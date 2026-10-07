-- V2__seed_demo.sql — clearly-fake demo dataset for user_id 'demo'.
-- Idempotent (fixed UUIDs + ON CONFLICT DO NOTHING). Resettable: delete all
-- rows with user_id = 'demo'. Never applied by the migrate tool in prod;
-- loaded explicitly via the demo-data loader (Phase 2).

-- Applications across stages, two of them stale by PLAN thresholds.
INSERT INTO applications
  (id, user_id, company, role, source, stage, applied_at, salary_min, salary_max, link, notes)
VALUES
  ('11111111-1111-4111-8111-111111111111', 'demo', 'Acme Corp', 'Backend Engineer',
   'referral', 'applied', now() - interval '9 days', 80000, 110000,
   'https://example.com/jobs/acme-backend', 'Demo data: met at meetup.'),
  ('22222222-2222-4222-8222-222222222222', 'demo', 'Globex', 'Flutter Developer',
   'job board', 'interview', now() - interval '4 days', 90000, 120000,
   'https://example.com/jobs/globex-flutter', 'Demo data: on-site next week.'),
  ('33333333-3333-4333-8333-333333333333', 'demo', 'Initech', 'Full-stack Engineer',
   'company site', 'screening', now() - interval '2 days', NULL, NULL,
   'https://example.com/jobs/initech-fullstack', 'Demo data: recruiter call done.'),
  ('44444444-4444-4444-8444-444444444444', 'demo', 'Umbrella', 'DevOps Engineer',
   'linkedin', 'offer', now() - interval '1 day', 100000, 130000,
   NULL, 'Demo data: offer letter received, review in progress.'),
  ('55555555-5555-4555-8555-555555555555', 'demo', 'Stark Industries', 'Mobile Engineer',
   'referral', 'saved', now() - interval '30 days', NULL, NULL,
   'https://example.com/jobs/stark-mobile', 'Demo data: interesting but not urgent.'),
  ('66666666-6666-4666-8666-666666666666', 'demo', 'Wayne Enterprises', 'QA Engineer',
   'job board', 'rejected', now() - interval '20 days', NULL, NULL,
   NULL, 'Demo data: rejected after screening.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO contacts (id, user_id, application_id, name, role, company, channels)
VALUES
  ('a1a1a1a1-a1a1-4a1a-8a1a-a1a1a1a1a1a1', 'demo',
   '11111111-1111-4111-8111-111111111111', 'Ada Example', 'Hiring Manager',
   'Acme Corp', '{"email": "ada@example.com"}'),
  ('b2b2b2b2-b2b2-4b2b-8b2b-b2b2b2b2b2b2', 'demo',
   '22222222-2222-4222-8222-222222222222', 'Bob Sample', 'Engineering Lead',
   'Globex', '{"email": "bob@example.com", "linkedin": "https://example.com/in/bob"}'),
  ('c3c3c3c3-c3c3-4c3c-8c3c-c3c3c3c3c3c3', 'demo', NULL, 'Cara Demo',
   'Recruiter', 'Tech Search', '{"email": "cara@example.com"}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO interactions
  (id, user_id, application_id, type, happened_at, summary, follow_up_at)
VALUES
  ('d1d1d1d1-d1d1-4d1d-8d1d-d1d1d1d1d1d1', 'demo',
   '11111111-1111-4111-8111-111111111111', 'email',
   now() - interval '9 days', 'Demo data: application sent with referral.',
   now() - interval '2 days'),
  ('d2d2d2d2-d2d2-4d2d-8d2d-d2d2d2d2d2d2', 'demo',
   '22222222-2222-4222-8222-222222222222', 'call',
   now() - interval '4 days', 'Demo data: screening call, positive signal.',
   now() + interval '2 days'),
  ('d3d3d3d3-d3d3-4d3d-8d3d-d3d3d3d3d3d3', 'demo',
   '33333333-3333-4333-8333-333333333333', 'call',
   now() - interval '2 days', 'Demo data: recruiter screen done.',
   NULL),
  ('d4d4d4d4-d4d4-4d4d-8d4d-d4d4d4d4d4d4', 'demo',
   '44444444-4444-4444-8444-444444444444', 'meeting',
   now() - interval '1 day', 'Demo data: final round, offer received.',
   now() + interval '6 days'),
  ('d5d5d5d5-d5d5-4d5d-8d5d-d5d5d5d5d5d5', 'demo',
   '66666666-6666-4666-8666-666666666666', 'email',
   now() - interval '15 days', 'Demo data: rejection received.',
   NULL)
ON CONFLICT (id) DO NOTHING;
