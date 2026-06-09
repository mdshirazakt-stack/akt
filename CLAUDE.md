# Apno Ki Talash — Claude Working Instructions

## Mandatory: Run /akt-review before every git push

Before running `git push` in this repo, **always** invoke `/akt-review` on the
diff. Do not skip it. The review skill catches project-specific bugs that are
invisible to generic review:

- Supabase RLS policy gaps (missing DELETE policies, auth_user_id-only clauses)
- Wrong column names (`email` omitted from SELECT, `mobile_number` vs `mobile`, etc.)
- Missing query columns used later in rendering code
- Global state assumptions (e.g. `allVisitors` assumed populated by another tab)
- XSS — unescaped user data in innerHTML
- PostgREST pitfalls (`.or()` with array, `.limit()` without `.order()`)
- Mobile UX issues (touch targets, unwrapped flex rows)

A pre-push hook enforces syntax checking and surfaces this reminder
automatically, but the hook cannot run the full skill — that requires you to
call it explicitly.

## Code conventions

- **Escape all user data** in innerHTML: `escapeHtml()` in admin.html,
  `escHtml()` in person.html, `escapeHtmlLocal()` in auth-flow.js
- **Never use `var(--rust)`** — use `var(--red)` (--rust is undefined)
- **Never use `escapeJs()`** — it does not exist; use the data-attribute pattern
- **Column names to remember:**
  - `visitors.name_entered` (not `name`)
  - `visitors.mobile` (not `mobile_number`)
  - `visitors.first_seen` (not `created_at`)
  - `families.marr_status` (not `status`)
- **RLS**: every new table needs `ENABLE ROW LEVEL SECURITY` + policies before
  it goes to production
- **auth-flow.js**: `appLaunched` guard must be checked in `onAuthStateChange`
  before calling `handleSession` again

## Self-contained data fetching

Any function that renders data must fetch what it needs itself — never assume
a global like `allVisitors` or `allProfileClaims` was populated by a different
tab or panel being opened first. If a render function depends on data, fetch
it inside that function or pass it explicitly as a parameter.
