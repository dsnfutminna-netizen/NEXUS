# NEXUS web application

Next.js App Router, TypeScript and Supabase. Deploy this directory as the Vercel project root. The existing Streamlit app remains in `../app`.

## Local setup

1. Install Node.js 24 and run `npm ci` in this directory.
2. Copy `.env.example` to `.env.local`, using a separate Supabase test project. Never use a service-role or secret key here.
3. Apply repository Supabase migrations in timestamp order and seed the reference catalog using the existing deployment tooling.
4. Set `NEXT_PUBLIC_SITE_URL` to your local origin and allow its authentication callback in Supabase.
5. Run `npm run dev` and open http://localhost:3000.

## Checks

- `npm test`: Python/TypeScript scoring parity and URL/date checks.
- `npm run test:db`: real PostgreSQL engine (PGlite), migrations and row-level permission checks. Does not contact hosted Supabase.
- `npx playwright install chromium` then `npm run test:e2e`: browser journeys against an isolated API double. No production accounts or database writes.
- `npm run build`: production compile and type validation.

See [migration and launch setup](../docs/web-migration.md). Local API doubles cannot establish email delivery, hosted Supabase compatibility, or production readiness.
