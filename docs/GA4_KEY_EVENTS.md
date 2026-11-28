# GA4 key events (console)

No Firebase Admin API in repo — register these manually in **Google Analytics**
→ **Admin** → **Events** → **Mark as key event** after `build_mode` = `release`
volume looks right.

| Event | Why |
|---|---|
| `rewarded_complete` | Rewarded ad finished — monetization core. |
| `store_purchase` | New Play grant (not restore). |

Also mark in Firebase **Analytics** → **Events** (same project as Play).

Do not double-count automatic `in_app_purchase` with `store_purchase`.