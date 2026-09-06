# Vanshavali — WhatsApp Invite Landing Page

`index.html` is the page an invitee sees when they tap a Vanshavali invite link
shared over WhatsApp. Because the app is sideloaded (not on the Play Store), a
raw `vanshavali://` link won't render or work reliably in WhatsApp, so this
hosted https page carries the invite instead.

The binding contract for this flow is
[`docs/whatsapp_invite_flow.md`](../docs/whatsapp_invite_flow.md) — read that
before changing anything here.

## What the page does

1. Parses the invite `code` and (optional) `name` from the URL query string.
2. Shows a warm, bilingual (English + Gujarati) invite message, personalized
   with the inviter's name when present.
3. **Download the app** → `https://github.com/Priyanshu-Prime/Vanshavali/releases/latest`
4. **Open in app** → fires the custom scheme `vanshavali://invite?code=<CODE>`,
   with a visible fallback message (~1.5s) if the app isn't installed.
5. **Always shows the 6-char code** in a large monospaced box with a
   **Copy code** button, so manual entry works even if deep linking fails.
6. If the code is missing or malformed, shows a helpful message + download
   button instead of a broken UI.

## URL parameter contract

```
https://priyanshu-prime.github.io/Vanshavali/?c=<CODE>&n=<url-encoded first name>
```

| Param | Required | Meaning |
|-------|----------|---------|
| `c`   | yes      | 6-character invite code (`SupabaseService.generateInviteCode`). Normalized to uppercase A–Z0–9; anything not exactly 6 chars triggers the "incomplete link" state. |
| `n`   | no        | Inviter's display name for friendly context. URL-encoded; used only as escaped text, capped at 40 chars. |

The "Open in app" button fires `vanshavali://invite?code=<CODE>`. The app must
also accept `?c=<CODE>` (see the contract's *App custom scheme* section).

## Design / constraints

- Single self-contained file: inline CSS + inline vanilla JS, **no external
  network requests, no CDN, no frameworks** — so it loads on 2G.
- Mobile-first, high contrast, 48px+ touch targets, warm heritage palette,
  inline SVG crest (no external images).
- Bilingual English + Gujarati throughout.
- Respects `prefers-color-scheme` (light default, dark variant).

## Deployment

GitHub Pages serves `landing/**` at the project site
`https://priyanshu-prime.github.io/Vanshavali/`. Deployment is handled by a
separate CI workflow (`.github/workflows/deploy-pages.yml`, written elsewhere) —
this directory contains only the static page. GitHub Pages must be enabled for
the repo (one-time owner step in the contract).
