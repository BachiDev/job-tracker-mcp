# job-tracker-mcp — Build Plan

> Owner: Fabian Bachmayer — fabian@bachi.dev — https://bachi.dev/work
> Repo (planned): `BachiDev/job-tracker-mcp` · Local: `C:\Users\PC\dev\job-tracker-mcp`
> Status: Neon linked (project `job-tracker-mcp`, branch `production`, Auth enabled,
> vars in `.env.local`) + environment ready (Flutter 3.47.6, Android toolchain + Chrome
> green). Next: Phase 0 scaffold.
> This doc is the single source of truth for a fresh session: read it before writing code.

## 1. What we are building

A **job-application tracker** — one pipeline for applications, contacts,
and follow-ups — as a **Flutter app (web + Android APK)**, backed by a **Dart server**
(typed API + real MCP server sharing one tool layer), on **Neon Postgres + Managed Better
Auth**, with a **BYOK chat** where an agent operates on the user's own pipeline.

Why it earns the 6th portfolio slot: the portfolio has no LLM and no MCP project; this fills
both, proves Flutter (advertised but unproven), and its visitors are hiring people who
understand the domain instantly.

Non-goals for v1: no iOS build (web is the iPhone path), no delete tool, no external sending
(agent drafts text, human sends), no realtime sync beyond request/response, no second backend
language, no analytics/tracking anywhere, no offline queue (friendly offline errors instead),
no push notifications.

## 2. Decisions (locked, with rationale)

| # | Decision | Rationale | Date |
|---|---|---|---|
| 1 | Domain: job-application tracker | One problem, parity everywhere, agent beats form, audience-fit | 2026-10-07 |
| 2 | Frontend: Flutter, web + APK only | One codebase; no App Store/Play Store hassle; APK sideloads, iOS uses web | 2026-10-07 |
| 3 | MCP server language: Dart (`mcp_dart`, `dart_mcp` fallback) | Single language, shared contracts; pin version, verify in Inspector at scaffold | 2026-10-07 |
| 4 | Data: Neon Postgres (Frankfurt region if offered) | Supabase free pauses after 1 week idle; Neon already proven via crm-demo | 2026-10-07 |
| 5 | Auth: Neon Managed Better Auth (Free: 60k MAU) | No extra vendor/bill; users synced to `neon_auth` schema; server verifies JWT via JWKS (Ed25519 — confirm Dart JWT-lib support at scaffold) | 2026-10-07 |
| 6 | Inference: BYOK, OpenAI-protocol client + presets v1 (OpenAI, Groq, OpenRouter, Ollama-local, Gemini via compat endpoint); Anthropic native adapter is stretch (different headers + tool format) | $0 infra, free-model-friendly; keys in secure storage (mobile) / browser storage (web), never leave the device except to the chosen provider | 2026-10-07 |
| 7 | Agent loop placement: client-side in the app | No backend needed for inference; server stays data + tools; key never forwarded | 2026-10-07 |
| 8 | State + routing: Riverpod + go_router | Testable, standard; go_router gives web deep-links (`?demo`, app routes) | 2026-10-07 |
| 9 | Server framework: shelf + shelf_router (default; dart_frog only if it clearly wins at scaffold) | Minimal, stable; MCP Streamable HTTP mounted alongside REST | 2026-10-07 |
| 10 | Editor: VS Code + Flutter extension | Owner's daily driver; Android Studio used only for AVD/SDK management | 2026-10-07 |
| 11 | Repo name: `job-tracker-mcp` | MCP emphasis; local `C:\Users\PC\dev\job-tracker-mcp`, planned `BachiDev/job-tracker-mcp` | 2026-10-07 |
| 12 | Server hosting: Render Docker (free tier) | Docker first-class; Dart AOT binary = small image, seconds-long wakes; shares the 750h/mo workspace budget with the Spring service (idle consumes zero — monitor dashboard) | 2026-10-07 |
| 13 | Auth methods: Google OAuth first, magic link second | Both supported by Managed Better Auth (magic link enabled per branch); hand-rolled REST client from Flutter, spiked in Phase 0 | 2026-10-07 |
| 14 | Demo mode: one-tap ephemeral demo account | Full experience incl. writes, clearly labeled, TTL cleanup; resolves `?demo=1` vs per-user scoping | 2026-10-07 |
| 15 | Transports v1: stdio + hosted Streamable HTTP | Hosted API exists anyway; MCP rides along under the same Bearer scheme | 2026-10-07 |

Open (decide at scaffold, not before): exact Dart package versions (pin all), migration runner
shape (plain `db/migrations/*.sql` + small migrate script is the default), coverage gate number
(default: ≥80% lines on `packages/core`), monorepo scripts (default: Melos), CI database
(default: long-lived `ci` Neon branch; ephemeral per-run branch optional).

## 3. Architecture (target)

```
job-tracker-mcp/
  app/                 # Flutter: web + android. Riverpod + go_router.
    lib/
      theme/           # bachi.dev tokens as ThemeData (see §5), bundled Inter + mono fonts
      features/
        auth/          # sign-in/out, session, key manager (BYOK)
        pipeline/      # board (web) / list (mobile), application detail, timeline
        contacts/      # contact list + detail
        chat/          # agent chat + tool-call trail + confirm sheets for writes
        settings/      # provider presets, demo-data loader, privacy note
      core/            # API client (Bearer JWT), agent loop, storage helpers
  packages/
    core/              # pure Dart, no Flutter: models, tool schemas + impls, scorer,
                       # validators, stage machine. Unit-tested, shared by app + server.
  server/              # Dart VM (shelf): REST API + MCP (stdio locally, Streamable HTTP
                       # hosted, both JWT-gated remotely). Ownership checks in every query.
  db/
    migrations/        # V1__init.sql (tables + indexes), V2__seed_demo.sql (demo dataset)
  evals/               # scripted fixtures: fixed inputs → expected tool-call sequences
  .github/workflows/   # ci.yml (analyze + test), release.yml (web + APK artifacts)
```

Data model (v1 tables): `applications(id, user_id, company, role, source, stage, applied_at,
salary_min, salary_max, link, notes, archived_at, …)`, `contacts(id, user_id, application_id?,
name, role, company, channels jsonb, …)`, `interactions(id, user_id, application_id, type,
happened_at, summary, follow_up_at, …)`. Stages (fixed enum): `saved, applied, screening,
interview, offer, accepted, rejected, withdrawn` (stale defaults: applied 7d, screening 5d,
interview 3d, offer 7d, saved none). Every row carries `user_id` from JWT `sub`;
server rejects cross-user access (test this explicitly).

MCP surface (all in `packages/core`, exposed by `server/`):
- Reads (free): `list_applications` (filters), `get_application`, `pipeline_summary`,
  `stale_followups`, `list_contacts`, `get_interactions`, `stats`.
- Writes (confirm-gated: chat shows exact args on a confirm sheet; over MCP the call must
  carry `confirmed: true`, which the app sets only after user approval): `add_application`,
  `update_stage`, `log_interaction`, `add_contact`, `schedule_followup`, `archive_application`.
- `draft_followup` returns text only. No delete tool, no send tool in v1.

Request flow (web/mobile): Flutter → `Authorization: Bearer <BetterAuth JWT>` → Dart server →
verify via JWKS → scope by `sub` → Postgres. Agent chat flow: app → provider API (BYOK key) →
tool calls executed against local `packages/core` impls hitting the server API → trail rendered →
writes paused on confirm sheets. OpenCode flow: stdio server locally (`dart run`) or hosted
Streamable HTTP with the same Bearer scheme.

Env contract (`.env.example`, never commit real values): `DATABASE_URL` (pooled),
`NEON_AUTH_BASE_URL`, `NEON_AUTH_JWKS_URL`, `NEON_AUTH_COOKIE_SECRET` (server-side only),
`API_BASE_URL` (app → server), demo flags. CI uses a Neon branch + throwaway auth env.

## 4. Phased roadmap (each phase merges green; do not start the next with red CI)

### Phase 0 — Foundations (no visuals)
- Scaffold `app/` (`flutter create` + Riverpod + go_router + flutter_lints), `packages/core/`,
  `server/` (shelf skeleton), `db/migrations/` folder, `.env.example`, CI skeleton.
- ~~Neon: project + Auth enabled~~ — done 2026-10-07 via CLI (Auth on, Google + magic-link
  providers on, password off; vars in `.env.local`). Fresh session: verify with
  `neon deploy` (expect "no changes") before scaffolding.
- `mcp_dart` pinned; stdio "hello tool" verified in MCP Inspector + connected once from OpenCode.
- JWT-verify spike in Dart (JWKS + Ed25519) against a real Neon Auth token — fail here, not later.
- Auth REST spike from Flutter (no Dart SDK exists): Google OAuth + magic-link sign-in,
  session attach, and token refresh, verified on web and Android — fail here, not in Phase 2.
- DoD: `dart analyze` + `flutter analyze` + tests (even 3 smoke tests) + `flutter build web`
  green in CI; README has run instructions.

### Phase 1 — Data + tools (the deliverable everything else frames)
- `V1__init.sql` (+ RLS-style ownership discipline in queries), `V2__seed_demo.sql`.
- REST: auth middleware, CRUD for all three entities, `stale_followups` + `stats` endpoints,
  `DELETE /account` (rows + auth-user removal, backs the privacy-note deletion path).
- `packages/core`: models, schemas, stage machine, validators; unit suite incl. cross-user
  rejection tests and stale-computation tests.
- Scripted `evals/` fixtures (no live LLM) wired into CI.
- DoD: API + core tests green, ≥80% lines on `packages/core`, Inspector lists all tools with
  schemas, OpenCode can call a read tool end-to-end (screenshot/GIF in README).

### Phase 2 — Flutter app (portfolio-visible)
- Theme port (§5), auth screens, BYOK key manager, pipeline board/list + detail + timeline,
  contacts, stats strip, settings incl. demo-data loader + privacy note.
- Chat: streaming, tool-call trail, confirm sheets for writes, error/empty/offline states.
- Seeded demo mode (`?demo=1` deep-link) for the 60-second web wow: "what needs my attention?"
- DoD: widget tests for pipeline + chat-confirm paths; manual pass on 360px + desktop web
  and on-device APK; no `print`, no hardcoded endpoints.

### Phase 3 — Ship the MCP story + release
- `server/` stdio packaging (`dart run` / compiled exe) + hosted Streamable HTTP deploy
  (free tier, Docker), Claude Desktop + OpenCode config snippets in README.
- Web release (hosting + install page linking the APK), APK artifact in CI releases
  (release keystore generated once by hand, stored in CI secrets).
- Link-preview/SEO for web (`index.html` meta + OG image + manifest + icons), README rewrite
  (architecture diagram, run, env, MCP proof, privacy), bachi.dev `/work` entry.
- DoD: release workflow produces web + APK from a tag; Inspector + OpenCode verified against
  the deployed server; OG unfurls.

### Phase 4 — Stretch (only after 0–3 ship)
Server-side scheduled digests, CSV import, interview-prep pack, second-stage analytics.
Explicitly not v1 (see §1 non-goals).

## 5. Design system (coherent with bachi.dev — copy, don't drift)

Source of truth: `BachiDev.github.io` tokens. Port to a single `AppTheme` (Material 3, dark only):
- Colors: base `#09090b` (zinc-950), raised `#18181b` (zinc-900); text `#f4f4f5` headings /
  `#d4d4d8`–`#a1a1a6` body (≥4.5:1); accent violet `#a78bfa`/`#8b5cf6`, fuchsia gradients sparingly;
  borders `white/10`; success/error emerald/red. One card style (rounded-xl, subtle violet hover),
  rounded-full pills/badges.
- Typography: **Inter** body/headings (tight headings), **mono accent only** (kickers, stats,
  tool-trail, IDs) — bundle both font files in-app (offline/APK-safe, OFL-licensed); never
  system-mono fallback as body.
- Language: kicker (mono, uppercase, violet) → H2 → lede section pattern, same as the site;
  Lucide-style icons only (no emojis as UI); stage pills color-coded *with labels*, never color-alone.
- Motion: micro-interactions only; respect `MediaQuery.disableAnimations` (reduced-motion);
  skeletons over spinners; reserve heights (no layout shift).
- Accessibility: Semantics labels on icon buttons and stage changes, visible focus indicators,
  minimum 44px targets, chat trail exposed to screen readers, keyboard-reachable web flows.

## 6. Testing plan

| Layer | Tool | What |
|---|---|---|
| Unit (core) | `dart test` | models, stage machine, validators, scorer, stale logic, schema validity; cross-user rejection |
| Server | `dart test` | auth middleware (401 paths), ownership scoping per endpoint, MCP tool wiring |
| Widget | `flutter test` | pipeline rendering incl. stale states, chat confirm-sheet accept/decline, auth gating |
| Evals (no LLM) | scripted fixtures | fixed inputs → expected tool-call sequences, run in CI |
| MCP interop | Inspector + OpenCode | tool list/call against local + deployed server (manual checklist, evidence in README) |
| Manual QA | checklist in PR template | auth flow, CRUD, chat + trail, BYOK set/clear per preset, offline/airplane, 360px + desktop, Safari (iPhone path), APK install + sideload guide accuracy, link preview |

Gates (CI, blocking): `analyze` (no infos), tests + core coverage gate, `flutter build web`
(+ APK on release). No live-LLM calls in CI ever. No secrets in git (`.env` gitignored,
gitleaks-style grep in CI optional).

## 7. Security rules (normative — violations block release)

Identity & sessions:
- Auth only via Neon Managed Better Auth; passwords/tokens never invented in-app.
- Server verifies every request's JWT against the JWKS endpoint (Ed25519); reject expired,
  wrong-issuer, or missing-`sub` tokens with 401, no fallback paths.
- Short-lived access (15-min tokens); app refreshes via the SDK, never caches a stale token
  past expiry; logout clears tokens + keys from device storage.

Authorization:
- Every row carries `user_id` from JWT `sub`; every query scopes by it — no unscoped reads,
  no admin bypass in v1, no cross-user access by construction (covered by tests, §6).
- MCP tools inherit the caller's identity: hosted HTTP requires the same Bearer JWT;
  local stdio trusts the local user only (document that stdio = full local access by design).

Agent writes & safety:
- Reads free; all six write tools confirm-gated (chat shows exact args, user approves).
- `draft_followup` is text-only; no email/SMS/send tool exists in v1, so the agent cannot
  act externally — state this in README and UI copy.
- No delete tool in v1 (`archive_application` only, reversible semantics).

Transport & secrets:
- HTTPS only in prod (no `http://` endpoints, no tokens in URLs or logs); security headers
  on web hosting; `Strict-Transport-Security` where the host allows it.
- Secrets live in env/CI secrets only (`.env` gitignored, `.env.example` documented);
  no key, secret, or connection string in git, logs, error messages, or client bundles.
- BYOK provider keys: secure storage on Android, browser storage on web, per-provider,
  user-clearable; sent only to the selected provider endpoint.

Input & data:
- Server-side validation on every write (stage enum, date sanity, length caps); parameterized
  queries only — no string-interpolated SQL, ever.
- PII minimization: store only what the tracker needs; demo dataset clearly fake and resettable;
  document a deletion path (delete account = delete rows) in the privacy note.
- Basic abuse guards on hosted endpoints (rate limiting + payload size caps) before release.

Supply chain:
- Pinned deps + lockfiles committed (`pubspec.lock`); `flutter pub deps` auditable;
  no `@latest`/unpinned CDN assets in web builds.

## 8. Content, copy, legal

- Voice: direct, senior, honest — same as bachi.dev. Every metric shown is computed, never invented.
- Demo honesty: seeded data labeled "Demo data"; BYOK screen states keys stay on-device;
  footer + README carry the privacy note (no tracking; keys only to chosen provider).
- Write-safety copy: confirm sheets show exact args before any mutation; drafts labeled
  "draft — nothing was sent".
- Assets: 1 OG/link-preview image, app icons, APK install mini-guide (unknown-sources steps).
- `/work` entry: outcome line + screenshots (web board + mobile + chat trail), stack pills
  (Flutter, Dart, MCP, Neon, Better Auth).

## 9. Risks & decisions log (append-only)

| # | Risk / decision | Mitigation / status |
|---|---|---|
| 1 | `mcp_dart` is community-maintained | Pin version; Inspector + OpenCode interop check in Phase 0; `dart_mcp` fallback |
| 2 | Dart JWT lib must support Ed25519 | Spike in Phase 0; fallback: verify via minimal `crypto` code, tested |
| 3 | Render-style free hosting sleeps | Dart cold starts in seconds; honest wake-up UX in app (same pattern as crm-demo) |
| 4 | Neon Free caps (1 GB storage, CU-hours) | Tracker rows are tiny; monitor dashboard quarterly; branch-per-env discipline |
| 5 | Scope creep (interview prep, CSV, digests) | Phase 4 only; v1 scope is §1 + §3, nothing more |
| 6 | Recruiter has no API key | Free-tier presets + scripted demo tour without a key (read-only trail) |
| 7 | Web cookie session attach fails with plain `package:http` (fetch hides `Set-Cookie`, drops x-origin cookies, verify URL unreadable — CORS) — proven by Phase 0 spike log 2026-10-07 | Phase 2: credentialed requests + server CORS headers, or non-cookie flow (JWT/bearer/server proxy) |
| 8 | Neon Auth requires callbackURL origin == request `Origin` (browsers always send it; non-browser clients skip the check) — proven 2026-10-07 | Local web: `--web-port 5000` + `http://localhost:5000` callback; Android (no Origin): `bachi.dev` callback; prod web (`bachi.dev` origin): `bachi.dev` callback |
| 9 | Android in-app magic-link verify session capture *assumed* working (IOClient has no Origin header, manual cookie jar; spike retired before final on-device proof to stop burning Phase 0 resources) | Phase 2 must prove it on-device: if session attach fails there, fall back to browser-surface verify (Custom Tabs). Web finding (row 7) stands regardless |
| 10 | Google sign-in has no in-app button in Phase 2 (magic-link + one-tap demo instead), despite decision 13 ranking it first | Rationale: on-device session attach is unproven for any browser-mediated flow (rows 7+9); a dead-end Google button would be worse than honest scope. Console provider stays enabled. Revisit when a browser-surface verify is proven |

## 10. Ship gate (all true before release)

- [ ] All tables user-scoped; cross-user tests green; no `/{document=**}`-style openness.
- [ ] Tool trail visible for every agent action; writes impossible without explicit confirm.
- [ ] Inspector + OpenCode verified (local and deployed); config snippets copy-paste work.
- [ ] Web + APK built from CI; install guide tested on a real device; link preview unfurls.
- [ ] No secrets in git, no tracking, privacy note shipped, README lets a stranger run it.
- [ ] bachi.dev `/work` entry live with outcome line + screenshots.

## 11. Immediate next actions

1. ~~Neon console (by hand): project in Frankfurt if offered → enable Auth → paste IDs/URLs into `.env`.~~ Done 2026-10-07 (CLI: linked `young-sea-65600244`/`production`, `auth: true` deployed, vars in `.env.local`). Still to confirm in console: magic-link toggle + Google OAuth provider.
2. Scaffold Phase 0 (packages layout + CI + hello-tool + JWT spike).
3. Review tool schemas *before* any chat UI (schemas are the deliverable, UI is the frame).
