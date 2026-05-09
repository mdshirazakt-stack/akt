# Apnon Ki Talash / Iraqi Biradari Project Handoff

Last updated: 2026-05-09

## Project Overview

This project has been split into two separate repositories and domains.

The split is intentional. The genealogy engine must remain isolated from the public heritage/content website so future CMS/admin work does not risk breaking Shijra functionality.

## Repository 1: `akt`

Purpose: genealogy engine only.

Local path:

```text
/Users/shiraz/apnonkitalash/akt
```

Domain:

```text
apnonkitalash.com
```

Expected root contents:

```text
CNAME
index.html
admin.html
allnames.json
legacy-code/
```

Important notes:

- `index.html` is the Shijra genealogy explorer.
- `admin.html` is the Shijra admin/import/export utility.
- `allnames.json` must stay beside `index.html`, because the explorer uses:

```js
fetch('allnames.json')
```

- `CNAME` should contain:

```text
apnonkitalash.com
```

- Do not move Shijra into `/shijra/` anymore.
- Do not add public heritage portal pages to this repo.
- Do not mix Iraqi Biradari CMS/admin content into this repo.

Current Git state/context:

- The repo was restored to genealogy-only.
- Latest local cleanup commit was:

```text
9f2f700 Restore akt as genealogy-only site
```

Check before continuing:

```bash
cd /Users/shiraz/apnonkitalash/akt
git status
```

If needed, push:

```bash
git push
```

## Repository 2: `iraqibiradari-site`

Purpose: public Iraqi Biradari heritage portal.

Local path:

```text
/Users/shiraz/apnonkitalash/iraqibiradari-site
```

Domain:

```text
iraqibiradari.com
```

Expected root contents:

```text
CNAME
index.html
about/
events/
documents/
videos/
contact/
admin/
assets/
```

Important notes:

- `CNAME` should contain:

```text
iraqibiradari.com
```

- All Shijra links in this repo should point to:

```text
https://apnonkitalash.com/
```

- Do not host or duplicate the genealogy engine inside this repo.
- This repo is for content, heritage pages, videos, PDFs, events, announcements, and future admin console.

Current Git state/context:

- The repo was initialized locally.
- Initial commit was:

```text
f8272c1 Initial heritage portal site
```

Check before continuing:

```bash
cd /Users/shiraz/apnonkitalash/iraqibiradari-site
git status
git remote -v
```

If remote is missing, add it after creating the GitHub repo:

```bash
git remote add origin git@github-akt:mdshirazakt-stack/iraqibiradari-site.git
git push -u origin main
```

If remote already exists, push:

```bash
git push -u origin main
```

## Domain / DNS Mapping

Use this final domain ownership:

```text
apnonkitalash.com  -> akt
iraqibiradari.com  -> iraqibiradari-site
```

For GitHub Pages apex domains, recommended DNS records are:

```text
Type: A
Host: @
Value: 185.199.108.153

Type: A
Host: @
Value: 185.199.109.153

Type: A
Host: @
Value: 185.199.110.153

Type: A
Host: @
Value: 185.199.111.153
```

For `www`:

```text
Type: CNAME
Host: www
Value: mdshirazakt-stack.github.io
```

Optional IPv6:

```text
Type: AAAA
Host: @
Value: 2606:50c0:8000::153

Type: AAAA
Host: @
Value: 2606:50c0:8001::153

Type: AAAA
Host: @
Value: 2606:50c0:8002::153

Type: AAAA
Host: @
Value: 2606:50c0:8003::153
```

Remove old/conflicting parking, forwarding, A, AAAA, or CNAME records for `@` and `www`.

## Design Direction For `iraqibiradari-site`

The site should feel like:

- historical archive
- manuscript collection
- cultural registry
- heritage institution

Preferred visual direction:

- deep green
- cream/off-white
- muted gold
- charcoal text
- subtle Islamic/archival influence
- timeless and calm

Avoid:

- startup aesthetic
- flashy gradients
- SaaS dashboard look
- excessive animation
- heavy frameworks

Technology:

```text
Static HTML
TailwindCSS via CDN for now
Vanilla JavaScript
Supabase later for content/admin data
GitHub Pages deployment
```

## Current `iraqibiradari-site` Pages

Created pages:

```text
/
/about/
/events/
/documents/
/videos/
/contact/
```

Future admin path:

```text
/admin/
```

Current public pages are static first-pass pages. They can be refined later.

## Supabase Decision

Do not use the existing Supabase account tied to:

```text
mdshiraz.akt@gmail.com
```

That account/project belongs to `apnonkitalash.com` / Shijra.

Recommended new account/project for Iraqi Biradari:

```text
Email: mdshiraz.ib@gmail.com
Project name: iraqibiradari-site
```

Reason:

- keeps genealogy data isolated
- keeps free-tier limits isolated
- avoids PDF/video storage pressure affecting Shijra
- separates admin credentials/API keys
- makes future maintenance cleaner

## Media Storage Recommendation

Do not store videos directly in Supabase.

Use:

```text
YouTube for videos
Google Drive or Supabase Storage for PDFs initially
Supabase DB only for metadata
```

Supabase should store metadata such as:

```text
title
description
youtube_url
pdf_url
thumbnail_url
event_date
category
priority
created_at
```

## Planned Supabase Tables

### `events`

```text
id
title
description
event_date
venue
banner_image
created_at
```

### `videos`

```text
id
title
youtube_url
description
thumbnail
created_at
```

### `documents`

```text
id
title
description
pdf_url
cover_image
category
created_at
```

### `announcements`

```text
id
title
body
priority
created_at
```

## Admin Console Scope

Build lightweight admin only for:

```text
Events
Videos
PDF documents/books
Announcements
```

Avoid building a full CMS initially.

Admin should support:

- add item
- edit item
- delete item
- list existing items
- simple authentication strategy, likely Supabase auth or password gate

Keep it simple and static-friendly.

## Next Recommended Steps

1. Confirm both repos are clean:

```bash
cd /Users/shiraz/apnonkitalash/akt
git status

cd /Users/shiraz/apnonkitalash/iraqibiradari-site
git status
```

2. Confirm both domains are correctly configured:

```text
apnonkitalash.com opens Shijra
iraqibiradari.com opens heritage portal
Shijra links from iraqibiradari.com open apnonkitalash.com
```

3. Create/use separate Supabase account:

```text
mdshiraz.ib@gmail.com
```

4. Create Supabase project:

```text
iraqibiradari-site
```

5. Create the four tables:

```text
events
videos
documents
announcements
```

6. Get Supabase values:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

7. Build `/admin/index.html` in `iraqibiradari-site`.

8. Connect public pages to Supabase data:

```text
/events/
/documents/
/videos/
homepage announcements/events/docs/videos sections
```

## Guardrails For Future Sessions

- Do not merge the two repos again.
- Do not move Shijra into `/shijra/`.
- Do not put Iraqi Biradari content admin into `akt`.
- Do not use the old Shijra Supabase project for portal data.
- Do not store heavy videos in Supabase.
- Keep `apnonkitalash.com` and `iraqibiradari.com` separate.
- Make small commits after each meaningful step.

## Quick Commands

Start local server for `akt`:

```bash
cd /Users/shiraz/apnonkitalash/akt
python3 -m http.server 8000
```

Open:

```text
http://localhost:8000/
http://localhost:8000/admin.html
```

Start local server for `iraqibiradari-site`:

```bash
cd /Users/shiraz/apnonkitalash/iraqibiradari-site
python3 -m http.server 8001
```

Open:

```text
http://localhost:8001/
http://localhost:8001/about/
http://localhost:8001/events/
http://localhost:8001/documents/
http://localhost:8001/videos/
http://localhost:8001/contact/
http://localhost:8001/admin/
```

