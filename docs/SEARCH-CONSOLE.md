# Google Search Console, step by step

An operator note, not repository content — it lives outside the five
checkouts on purpose.

The site is `https://dynamic-config-rs.github.io/` and it publishes a
sitemap at `/sitemap.xml` (written by `site.yml` from what was actually
built, 79 pages at the last count). Search Console is what tells Google the
sitemap exists, shows which pages were indexed and which were not, and why.

---

## 1. Which property to add

Two kinds exist, and for a `github.io` subdomain only one of them works:

| Property type | Works here? |
|---|---|
| **Domain** (`dynamic-config-rs.github.io`) | ❌ needs a DNS TXT record, and you do not control `github.io`'s DNS |
| **URL prefix** (`https://dynamic-config-rs.github.io/`) | ✅ this one |

Add it at <https://search.google.com/search-console> → *Add property* →
**URL prefix** → paste `https://dynamic-config-rs.github.io/`.

## 2. Verification

Google offers five methods. Three of them cannot work on GitHub Pages
(DNS, Google Analytics, Tag Manager unless you already use them), which
leaves:

### Option A — HTML file (recommended)

Google gives you a file named like `google1a2b3c4d5e6f7g8.html`. It has to
be served at the site root. The site is assembled by a workflow, so the
file belongs in the docs repository and gets copied into the artefact:

```sh
cd /home/ctolon/rust-project-templates/dynamic-config-rs/dynamic-config-rs.github.io

mkdir -p static
# save the file Google gave you as static/google<...>.html
```

Then teach the workflow to carry it — one step, after the books are built
and before the artefact is uploaded (`.github/workflows/site.yml`):

```yaml
      # Anything that has to be served from the site root but is not a
      # book: Search Console's verification file, and whatever joins it.
      - name: static files
        run: |
          if [ -d site/static ]; then
            cp -a site/static/. out/
          fi
```

`site/` is where this repository is checked out in that workflow, so
`site/static/google….html` lands at `out/google….html` → served at
`https://dynamic-config-rs.github.io/google….html`.

Push, let `Site` run, confirm the URL answers 200, then press **Verify**.

### Option B — HTML tag

Google gives a `<meta name="google-site-verification" content="…">`. It has
to appear in `<head>` of the site root. mdBook renders `theme/head.hbs`
into every page's head, so this means adding that file to the *engine's*
book (`dynamic-config/book/theme/head.hbs`) — a repository away from the
site, and it would put the tag on every page rather than one. Option A is
cleaner for exactly that reason.

## 3. Submit the sitemap

Once verified: *Sitemaps* → enter `sitemap.xml` → **Submit**.

Google reads it within a day or two. `robots.txt` already points at it, so
this only speeds things up rather than enabling anything.

## 4. What to check afterwards

- **Pages** → *Indexed* climbs over days, not minutes. 79 pages is the
  ceiling; `print.html` is excluded on purpose (each is a whole book on one
  page, which reads as duplicate content).
- **Pages → Not indexed → "Excluded by ‘noindex’ tag"** will list the
  *old* site's pages if that property is ever added. That is intended:
  `ctolon.github.io/dynamic-config` serves `noindex, follow` so it leaves
  the index while still passing its links on.
- **Settings → Ownership verification** — keep the HTML file in the
  repository. Deleting it un-verifies the property silently.

## 5. Bing, while you are there

Bing Webmaster Tools (<https://www.bing.com/webmasters>) has an *Import
from Google Search Console* button that copies the property and the
sitemap in one click. Worth the two minutes: it also feeds DuckDuckGo.

---

## What is already done, so you do not redo it

- `sitemap.xml` — generated per deploy from the built pages, with
  `lastmod`.
- `robots.txt` — allows everything except the four `print.html` pages, and
  names the sitemap.
- `noindex, follow` on the three books of the archived repository, so the
  old copies leave the index instead of competing with the new site.
- Canonical tags are deliberately **not** used: `noindex` and `canonical`
  are contradictory instructions, and mdBook's `{{ path }}` yields the
  source `.md` name rather than the published `.html` one.
