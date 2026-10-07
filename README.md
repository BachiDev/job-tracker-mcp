# job-tracker-mcp (Phase 1)

Job-application tracker — Flutter app (web + APK) + Dart server (REST + MCP)
on Neon Postgres + Managed Better Auth, with BYOK chat. See [`PLAN.md`](PLAN.md)
(single source of truth).

> Phase 1 status: data + tools. REST CRUD, 14 MCP tools, migrations, evals.
> Manual DoD pending: Inspector tool list/call + OpenCode read-tool evidence.

## Pinned versions (Phase 0)

| Dep | Version | Why |
|---|---|---|
| Flutter | 3.47.6 | env-ready (PLAN §1) |
| Dart SDK | ^3.13.5 | `flutter --version` |
| `mcp_dart` | **2.4.2** (exact) | PLAN decision 3 |
| `flutter_riverpod` | 3.4.3 | `flutter pub add` 2026-10-07 |
| `go_router` | 18.0.2 | same |
| `shelf` / `shelf_router` | ^1.4.2 / ^1.1.2 | server template |
| `cryptography` | ^2.9.0 | Ed25519 verify (PLAN risk #2 fallback) |
| `postgres` | 3.5.20 | server DB driver (pinned at Phase 1 scaffold) |
| `http` | ^1.5.0 | server JWKS fetch |
| `flutter_lints` / `lints` | ^6.0.0 | template default |

Coverage gate: ≥80% lines on `packages/core` (enforced from Phase 1).
Monorepo scripts: Melos (`melos.yaml`). CI DB: long-lived `ci` Neon branch (Phase 1).

## Run

```bash
# 0. Verify Neon link (expect "No changes")
npx neon deploy

# 1. Deps
cd packages/core && dart pub get
cd ../../server && dart pub get
cd ../app && flutter pub get
# or: dart pub global activate melos && melos run get

# 2. Analyze + tests
cd packages/core && dart analyze --fatal-infos && dart test
cd ../../server && dart analyze --fatal-infos && dart test
cd ../app && flutter analyze --no-pub && flutter test

# 3. Server (REST skeleton)
cd server && dart run bin/server.dart
# → http://localhost:8080/health

# 3b. Database (ci branch for tests; migrate is idempotent)
dart run tool/migrate.dart --database-url "$TEST_DATABASE_URL"
# --seed also applies V2 demo data (dev only, never prod)

# 4. MCP stdio (full v1 surface; local user only by design)
cd server
JOB_TRACKER_USER_ID=<your-sub> DATABASE_URL=<url> dart run bin/mcp_stdio.dart --user <your-sub>
# Inspector: npx @modelcontextprotocol/inspector --cli dart run bin/mcp_stdio.dart --user <sub> --method tools/list
# OpenCode: connect once over stdio (see below)

# 5. Evals (scripted, no LLM)
cd server && dart run tool/evals.dart --dir ../evals/fixtures

# 5. Web build smoke
cd app && flutter build web --no-pub
```

## MCP (Phase 1)

14 tools from `packages/core` (`toolDefs`), exposed over stdio
(`server/bin/mcp_stdio.dart`). Reads free; writes need `confirmed: true`
(chat confirm sheets set it after user approval); `draft_followup` is
text-only; no delete/send tool exists.

OpenCode local config snippet:

```json
{
  "mcp": {
    "servers": {
      "job-tracker": {
        "command": ["dart", "run", "bin/mcp_stdio.dart", "--user", "<your-sub>"],
        "cwd": "<repo>/server",
        "env": {
          "DATABASE_URL": "<pooled-url>",
          "JOB_TRACKER_USER_ID": "<your-sub>"
        }
      }
    }
  }
}
```

## Privacy / deletion

`DELETE /api/account` (Bearer JWT) deletes all rows of the caller
(interactions → contacts → applications, transactional). Removing the auth
user itself is a Neon console step (Auth → Users); the response states this.

## JWT spike (Phase 0 DoD)

`server/lib/auth/jwt_verify.dart` verifies Ed25519 (EdDSA) JWTs against the
Neon Auth JWKS via `package:cryptography` (no dependency on
`dart_jsonwebtoken` EdDSA support).

```bash
cd server
dart run tool/jwt_spike.dart --token <BETTER_AUTH_JWT>
# expect: OK sub=<...>
```

Get a token: sign in via the Neon Auth endpoint
(`NEON_AUTH_BASE_URL` in `.env.local`), then pass the session JWT.
Google OAuth + magic-link REST spike from Flutter is tracked for Phase 0 exit
(manual checklist: web + Android attach + refresh).

### Auth spike (Phase 0, retired — findings kept)

The throwaway spike screen (`/spike`: magic-link, in-app verify, session,
JWT, Google URL) was removed after it delivered its findings; the remaining
Android-verify assumption is logged in PLAN §9 row 9 and must be proven in
Phase 2. Findings that stand:

- Magic-link request works from any client; callbackURL origin must equal the
  request `Origin` (local web: `--web-port 5000` + `http://localhost:5000`;
  Android/prod per PLAN §9 row 8).
- Web cookie session attach is unworkable with plain `package:http`
  (PLAN §9 row 7) — Phase 2 needs credentialed requests + CORS or a
  non-cookie flow on web regardless.

## Env

Copy [`.env.example`](.env.example) → `.env.local` (gitignored).
`npx neon deploy` refreshes `DATABASE_URL*` + `NEON_AUTH_*` automatically.

## Layout

```text
app/            Flutter (Riverpod + go_router)
packages/core/  pure Dart domain (stage machine, validators)
server/         shelf REST + MCP stdio (+ Streamable HTTP in Phase 3)
db/migrations/  V1 lands in Phase 1
.github/        ci.yml (analyze + test + build web)
```
