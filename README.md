# job-tracker-mcp (Phase 0)

Job-application tracker — Flutter app (web + APK) + Dart server (REST + MCP)
on Neon Postgres + Managed Better Auth, with BYOK chat. See [`PLAN.md`](PLAN.md)
(single source of truth).

> Phase 0 status: scaffold + hello-tool + JWT spike. Pipeline UI lands in Phase 2.

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

# 4. MCP stdio hello-tool
cd server && dart run bin/mcp_stdio.dart
# Inspector: npx @modelcontextprotocol/inspector dart run bin/mcp_stdio.dart
# OpenCode: connect once over stdio (see below)

# 5. Web build smoke
cd app && flutter build web --no-pub
```

## MCP (Phase 0)

Stdio entry: `server/bin/mcp_stdio.dart` — one `hello` tool (`{name?}` → greeting).

OpenCode local config snippet:

```json
{
  "mcp": {
    "servers": {
      "job-tracker": {
        "command": ["dart", "run", "bin/mcp_stdio.dart"],
        "cwd": "<repo>/server"
      }
    }
  }
}
```

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
