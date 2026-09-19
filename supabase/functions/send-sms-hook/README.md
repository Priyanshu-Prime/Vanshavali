# `send-sms-hook` — phone OTP delivery via Fast2SMS

This Edge Function is the **Supabase "Send SMS" auth hook**. Supabase Auth
(GoTrue) still generates, stores, and verifies the 6-digit OTP; this function
only *delivers* the code — through **Fast2SMS** instead of Twilio.

**Cost:** ~₹0.20–0.30/SMS (~₹200/mo at this village's volume, prepaid wallet —
no subscription) vs ~₹7/SMS on Twilio.

**DLT is mandatory:** India's TRAI rules require DLT registration for *all*
automated SMS — there is no legal SMS path in India that skips it. So this uses
Fast2SMS's **DLT route** with your own approved sender/header + OTP template.
The one-time DLT registration (free, ~2–7 days) is step 1 below.

The phone-login UI in the app (`PhoneAuthScreen`, `AuthProvider.sendPhoneOtp` /
`verifyPhoneOtp`) is already built and needs no change — it talks to standard
Supabase phone auth. Only the one-time setup below remains.

---

## One-time setup (owner — needs a Fast2SMS account, a DLT registration, and the Supabase dashboard)

### 1. DLT registration (free, one-time, ~2–7 days for approval)
Register once on **any one** operator's DLT portal — it's shared across all
operators. Common choices: Jio **trueconnect.jio.com**, Vi **vilpower.in**,
Airtel **dlt.airtel.in**, BSNL **ucc-bsnl.co.in**.

1. **Register as a Principal Entity (PE):** sign up as an enterprise, provide a
   **PAN** (a personal PAN works on most portals — you register as an
   individual/proprietor; GST helps but isn't mandatory), authorized-person
   details, and address proof. You'll receive a **19-digit Entity ID (PE ID)**.
2. **Register a Header (sender ID):** request a 6-character alphabetic header,
   e.g. `VNSHVL`, under the **Service/Transactional** category. Approval 1–2 days.
3. **Register the OTP content template** under the **Service (OTP)** category.
   Register this **exact** text so it matches what the function sends (one
   variable for the code):

   ```
   {#var#} is your OTP for Vanshavali. Do not share it with anyone.
   ```

   You'll receive a **DLT template ID** for it. (You can word it differently —
   just keep exactly one `{#var#}` for the OTP; the function only sends the code.)

### 2. Fast2SMS account + link your DLT details
1. Sign up at https://www.fast2sms.com and add wallet balance (₹200–₹500 to start).
2. **DLT section** → enter your **Entity ID (PE ID)**, then add your approved
   **Header** and your **OTP template**. Fast2SMS assigns the template a numeric
   **Message ID** — this is `FAST2SMS_DLT_MESSAGE_ID` below (not the DLT portal's
   template ID).
3. Dashboard → **Dev API** → copy your **API Key** (`FAST2SMS_API_KEY`).

### 3. Deploy this function + set its secrets
From the repo root, with the Supabase CLI logged in and linked to the project:

```bash
# Generate a hook secret (any strong random base64, prefixed as Supabase expects)
#   example: openssl rand -base64 32   -> then prefix with "v1,whsec_"
supabase secrets set \
  FAST2SMS_API_KEY="<your fast2sms api key>" \
  SEND_SMS_HOOK_SECRET="v1,whsec_<your base64 secret>" \
  FAST2SMS_SENDER_ID="<your approved 6-char header, e.g. VNSHVL>" \
  FAST2SMS_DLT_MESSAGE_ID="<the numeric Fast2SMS message id for your template>"

# --no-verify-jwt: GoTrue calls this server-to-server with the webhook
# signature, not an end-user JWT.
supabase functions deploy send-sms-hook --no-verify-jwt
```

(If `FAST2SMS_SENDER_ID` / `FAST2SMS_DLT_MESSAGE_ID` are omitted, the function
falls back to Fast2SMS's legacy OTP route — only for dev/testing; production
must use the DLT route above.)

The function URL will be:
`https://<project-ref>.supabase.co/functions/v1/send-sms-hook`

### 4. Enable Phone auth + point it at this hook (Supabase Dashboard)
1. **Authentication → Providers → Phone**: toggle **Enable phone provider ON**.
   Leave "Enable phone confirmations" as you prefer; SMS OTP sign-in works
   regardless. Do **not** fill in Twilio/Vonage credentials.
2. **Authentication → Hooks** (or Auth → Hooks) → **Send SMS hook**:
   - Enable it, select **HTTPS**.
   - URL: the function URL above.
   - Secret: the **same** `v1,whsec_...` value you set as `SEND_SMS_HOOK_SECRET`.

That's it. A phone login now: app calls `signInWithOtp(phone:)` → GoTrue makes
the OTP → calls this hook → Fast2SMS texts the code → user enters it →
`verifyOTP` completes the sign-in.

---

## Verifying / troubleshooting
- **Function logs:** Dashboard → Edge Functions → `send-sms-hook` → Logs. Every
  failure is logged with the provider's own message (wallet empty, invalid key,
  bad number) so you can diagnose without reproducing on a device.
- **`Invalid webhook signature` (401):** the dashboard hook secret and the
  `SEND_SMS_HOOK_SECRET` function secret don't match. Re-set both to the same
  `v1,whsec_...` string.
- **`SMS provider could not deliver` (502):** check the logged provider message.
  Common DLT causes: empty Fast2SMS wallet; the sender/template not yet approved
  (still pending on the DLT portal); `FAST2SMS_SENDER_ID` or
  `FAST2SMS_DLT_MESSAGE_ID` not matching the approved header/template; or a
  message that doesn't match the registered template (this function sends only
  the OTP into a single `{#var#}`, so keep the template to one variable).
- **Only +91 numbers** are accepted; `toIndianMobile()` strips `+91`. Widen it
  if the community ever spans other countries.

## Local development
`supabase/config.toml` has a `[auth.hook.send_sms]` block pointing at the local
functions server; put `FAST2SMS_API_KEY` and `SEND_SMS_HOOK_SECRET` in
`supabase/.env.local` and run `supabase functions serve send-sms-hook` alongside
`supabase start`.
