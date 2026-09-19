// Supabase "Send SMS" auth hook.
//
// Why this exists: Supabase's built-in SMS providers (Twilio, Vonage, ...) are
// prohibitively expensive for India (₹6-7+ per segment, doubled for Gujarati
// Unicode, plus mandatory self-DLT registration). This project targets a
// ~500-person village at strict zero/near-zero cost. So instead of letting
// GoTrue deliver the OTP itself, we register THIS function as the "Send SMS"
// hook: GoTrue still generates + stores + verifies the OTP, and just hands us
// the code to deliver. We forward it through Fast2SMS (~₹0.20-0.30 per SMS,
// ~₹200/mo at this volume). India's TRAI rules require DLT registration for
// all automated SMS, so this uses Fast2SMS's DLT route with the owner's own
// approved sender/header + OTP template (see README.md for the one-time
// registration).
//
// Contract (Supabase Send SMS hook):
//   - Request is signed with the Standard Webhooks scheme using the hook
//     secret (SEND_SMS_HOOK_SECRET). We MUST verify it — the endpoint is
//     public, and an unverified endpoint is a free SMS-spend faucet for anyone
//     who finds the URL.
//   - Body: { user: { phone }, sms: { otp } }. phone is E.164 (e.g.
//     "+919876543210"); GoTrue has already rendered/stored the OTP.
//   - Return 200 on success. On failure return a non-2xx with
//     { error: { http_code, message } } so GoTrue surfaces a real error to
//     the client instead of pretending the SMS was sent.
//
// Deploy:  supabase functions deploy send-sms-hook --no-verify-jwt
//   (--no-verify-jwt because GoTrue calls this server-to-server with the
//    webhook signature, not a user JWT.)
// Secrets: supabase secrets set FAST2SMS_API_KEY=... SEND_SMS_HOOK_SECRET=v1,whsec_... \
//            FAST2SMS_SENDER_ID=<approved header> FAST2SMS_DLT_MESSAGE_ID=<fast2sms template id>
// See README.md in this folder for the full one-time setup + DLT registration.

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const FAST2SMS_ENDPOINT = "https://www.fast2sms.com/dev/bulkV2";

interface SendSmsPayload {
  user: { phone: string };
  sms: { otp: string };
}

/**
 * Fast2SMS's OTP route takes a bare 10-digit Indian mobile number (no country
 * code, no "+"). GoTrue gives us E.164. Strip a leading "+" and a "91" country
 * code so "+919876543210" -> "9876543210". Leaves already-bare numbers alone.
 */
function toIndianMobile(phone: string): string {
  let digits = phone.replace(/[^\d]/g, ""); // drop "+", spaces, dashes
  if (digits.length === 12 && digits.startsWith("91")) {
    digits = digits.slice(2);
  }
  return digits;
}

function errorResponse(httpCode: number, message: string): Response {
  // GoTrue reads this shape and propagates `message` to the auth client.
  return new Response(
    JSON.stringify({ error: { http_code: httpCode, message } }),
    { status: httpCode, headers: { "Content-Type": "application/json" } },
  );
}

Deno.serve(async (req) => {
  const hookSecret = Deno.env.get("SEND_SMS_HOOK_SECRET");
  const apiKey = Deno.env.get("FAST2SMS_API_KEY");

  if (!hookSecret || !apiKey) {
    // Misconfiguration, not a caller error. 500 so it shows up in logs as ours.
    console.error("send-sms-hook: missing SEND_SMS_HOOK_SECRET or FAST2SMS_API_KEY");
    return errorResponse(500, "SMS delivery is not configured.");
  }

  const rawBody = await req.text();

  // 1) Verify the Standard Webhooks signature. The Supabase-issued secret is
  //    formatted "v1,whsec_<base64>"; the library wants just the base64 part.
  let payload: SendSmsPayload;
  try {
    const wh = new Webhook(hookSecret.replace("v1,whsec_", ""));
    payload = wh.verify(rawBody, Object.fromEntries(req.headers)) as SendSmsPayload;
  } catch (err) {
    console.error("send-sms-hook: signature verification failed", String(err));
    return errorResponse(401, "Invalid webhook signature.");
  }

  const phone = payload.user?.phone;
  const otp = payload.sms?.otp;
  if (!phone || !otp) {
    return errorResponse(400, "Missing phone or OTP in hook payload.");
  }

  const mobile = toIndianMobile(phone);
  if (mobile.length !== 10) {
    console.error(`send-sms-hook: unexpected phone format "${phone}" -> "${mobile}"`);
    return errorResponse(400, "Only Indian (+91) mobile numbers are supported.");
  }

  // 2) Deliver via Fast2SMS.
  //    India's TRAI rules require DLT registration for all A2P SMS, so the
  //    normal path is the DLT route: it needs your approved sender/header
  //    (FAST2SMS_SENDER_ID) and the Fast2SMS message-template id
  //    (FAST2SMS_DLT_MESSAGE_ID) for the OTP template you registered. The OTP
  //    itself goes in `variables_values`, filling the template's {#var#}.
  //    (If both DLT vars are absent we fall back to the legacy OTP route so a
  //    dev/test project without DLT still works — but production must use DLT.)
  const senderId = Deno.env.get("FAST2SMS_SENDER_ID");
  const dltMessageId = Deno.env.get("FAST2SMS_DLT_MESSAGE_ID");

  const params = new URLSearchParams({
    variables_values: otp,
    numbers: mobile,
    flash: "0",
  });
  if (senderId && dltMessageId) {
    params.set("route", "dlt");
    params.set("sender_id", senderId);
    params.set("message", dltMessageId);
  } else {
    console.warn("send-sms-hook: DLT env vars not set — using legacy OTP route");
    params.set("route", "otp");
  }

  let f2sResp: Response;
  try {
    f2sResp = await fetch(`${FAST2SMS_ENDPOINT}?${params.toString()}`, {
      method: "GET",
      headers: { authorization: apiKey },
    });
  } catch (err) {
    // Network failure reaching the provider — transient, tell the client to retry.
    console.error("send-sms-hook: fetch to Fast2SMS failed", String(err));
    return errorResponse(502, "Could not reach the SMS provider. Please try again.");
  }

  const body = await f2sResp.text();
  let parsed: { return?: boolean; message?: unknown } = {};
  try {
    parsed = JSON.parse(body);
  } catch (_) {
    // Non-JSON body from the provider — treat the HTTP status as the signal.
  }

  if (!f2sResp.ok || parsed.return === false) {
    // Log the provider's message (wallet empty, invalid number, bad key, ...)
    // so failures are diagnosable from the function logs without a repro.
    console.error(
      `send-sms-hook: Fast2SMS rejected (status=${f2sResp.status}): ${body}`,
    );
    return errorResponse(502, "The SMS provider could not deliver the code.");
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
