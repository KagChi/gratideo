# Gratideo backend

Cloudflare Worker (Hono + D1) that owns Gratideo accounts. The phone derives a
PBKDF2-SHA256 verifier with the password, so the Worker never sees or hashes a
password: it stores `HMAC-SHA256(PEPPER, verifier)` and matches it on sign in.

Live deployment: <https://gratideo-api.im-maxyacademy.workers.dev>

## Endpoints

| Method | Path | Body | Answer |
| --- | --- | --- | --- |
| GET | `/health` | – | `{ ok: true }` |
| POST | `/v1/auth/register` | `{name, email, verifier, kdf:{algo, iterations}}` | 201 `{token, expiresAt, user}` |
| POST | `/v1/auth/login` | `{email, verifier}` | 200 `{token, expiresAt, user}` |
| GET | `/v1/auth/me` | Bearer token | `{user}` |
| POST | `/v1/auth/logout` | Bearer token | 204 |
| POST | `/v1/auth/password/reset-request` | `{email}` | 202 (no mail is sent yet) |
| POST | `/v1/sync` | `{since, prayers[], thanks[], entries[]}` | `{serverTime, prayers, thanks, entries}` |
| GET | `/v1/sync?since=` | Bearer token | `{serverTime, prayers, thanks, entries}` |

Errors are `{ error: { code, message } }`. Sessions are opaque 32-byte tokens,
stored as SHA-256 hashes, and expire after 30 days.

Sync rows are keyed by uuid and merged last-write-wins on `updatedAt`; deletions travel
as tombstones (`deletedAt`) so removing something on one phone removes it everywhere.
Each account only ever sees its own rows.

## Local work

```sh
pnpm install
cp .dev.vars.example .dev.vars        # set PEPPER
pnpm exec wrangler d1 migrations apply gratideo-db --local
pnpm test                            # workerd + D1, 15 tests
pnpm dev
```

## Deploying

```sh
export CLOUDFLARE_API_TOKEN=... CLOUDFLARE_ACCOUNT_ID=...
pnpm exec wrangler d1 create gratideo-db          # once, then paste the id into wrangler.jsonc
pnpm exec wrangler d1 migrations apply gratideo-db --remote
openssl rand -base64 32 | pnpm exec wrangler secret put PEPPER
pnpm exec wrangler deploy
```

`PEPPER` must stay secret and stable: changing it invalidates every stored verifier.

GitHub Actions mirrors this: `Backend` runs typecheck, tests and a dry-run build on
every push, and deploys `main` when `vars.CLOUDFLARE_ACCOUNT_ID` is set, using
`secrets.CLOUDFLARE_API_TOKEN`.

## Checking it by hand

```sh
VERIFIER=$(python3 - <<'PY'
import base64, hashlib
email, password = "you@example.com", "Gratideo2026!"
salt = hashlib.sha256(("gratideo|v1|" + email).encode()).digest()[:16]
print(base64.b64encode(hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 210000, 32)).decode())
PY
)

curl -s -X POST https://gratideo-api.im-maxyacademy.workers.dev/v1/auth/register \
  -H 'content-type: application/json' \
  -d "{\"name\":\"You\",\"email\":\"you@example.com\",\"verifier\":\"$VERIFIER\",\"kdf\":{\"algo\":\"pbkdf2-sha256\",\"iterations\":210000}}"
```

Documents (R2) are not wired up yet.

