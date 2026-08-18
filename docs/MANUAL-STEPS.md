# The six things a script cannot do

Everything here needs a browser, a password prompt or a decision. Each
section says what it buys, what to click, and how to check it worked. An
operator note — it lives outside the five checkouts on purpose.

Ordered by value per minute:

| # | Step | Time | Buys |
|---|---|---|---|
| 1 | crates.io e-mail verification | 2 min | publishing at all |
| 2 | Discussions — seed the empty tab | 10 min | questions become findable pages |
| 3 | Pinned repositories | 2 min | the org page stops looking random |
| 4 | Social preview images | 20 min | a card instead of a bare link |
| 5 | PyPI trusted publishing | 15 min | no token to rotate, a verified badge |
| 6 | Search Console + Bing | 15 min | the site gets indexed on purpose |

---

## 1. crates.io e-mail verification

**Why first:** an unverified address cannot publish. The release workflow
would fail at the first `cargo publish` with `A verified email address is
required`, after the tag has already been minted.

1. <https://crates.io> → sign in with GitHub → avatar → **Account
   Settings**.
2. If the address shows *unverified*, press **Resend** and click the link
   in the mail.

**Check:**

```sh
# the token in the crates-io environment belongs to this account, so this
# is the account that must be verified
gh api user -q .email
```

There is no API for the verification state; the settings page is the only
place it is shown.

## 2. Discussions

**Why:** a question asked in an issue is closed and forgotten; the same
question in a discussion stays indexed and answers the next person. It is
also where "who is using this" lives, which is the thread that matters
most before 1.0.

**Already on for the engine** (`has_discussions: true`), and off for the
other three — which is the right split: one place to ask beats four empty
ones, and the issue templates in the other repositories already point at
it.

```sh
# only if you decide otherwise later
gh repo edit dynamic-config-rs/dynamic-config --enable-discussions
```

What is missing is content: the tab has **0 discussions**, and an empty
Discussions tab reads worse than none. Seed it with three:

- **Announcements** → "dynamic-config has moved to its own organisation"
  (what changed, what did not, the four repositories).
- **Show and tell** → "Who is using this?" — one post, pinned.
- **Q&A** → nothing yet; the first real question starts it.

**Check:**

```sh
gh api repos/dynamic-config-rs/dynamic-config -q .has_discussions
```

## 3. Pinned repositories on the organisation page

**Why:** without pins, `github.com/dynamic-config-rs` lists repositories by
last push — so the docs site or whatever was touched last leads, and a
visitor cannot tell which one to install.

There is no CLI or API for this: GitHub's GraphQL has `pinIssue` and
friends but no mutation for an organisation's pinned repositories. It is
the web UI, once:

1. <https://github.com/dynamic-config-rs> → **Customize pins** (top right
   of the repository list).
2. Tick, in this order — the list renders in the order you tick:
   `dynamic-config`, `dynamic-config-remote`, `dynamic-config-python`,
   `dynamic-config-node`.
3. Leave `dynamic-config-rs.github.io` and `.github` unpinned: one is the
   site's plumbing, the other is the profile the visitor is already
   reading.

## 4. Social preview images

**Why:** every link to these repositories — a post, a Slack message, a
tweet — currently renders as a grey Octocat card. A preview image is the
difference between "some repo" and a name somebody remembers.

**The format GitHub wants:** 1280×640 px, PNG or JPG, under 1 MB. Anything
else is scaled and cropped from the centre, so keep the text inside the
middle 1120×480.

**Making them.** The tooling is already on this machine (`rsvg-convert`,
ImageMagick). One SVG per repository, same layout, different title and
accent — write the SVG, then:

```sh
rsvg-convert -w 1280 -h 640 social-core.svg -o social-core.png
```

Suggested content, one line each, in the project's own voice:

| Repository | Title | Line under it |
|---|---|---|
| `dynamic-config` | dynamic-config | Hot-reloadable, lock-free configuration for Rust |
| `dynamic-config-remote` | dynamic-config-remote | etcd · Consul · Vault · NATS · Redis · S3 · Firestore · git |
| `dynamic-config-python` | dynamic-config-py | Rust resolves, your schema validates |
| `dynamic-config-node` | dynamic-config-node | Rust resolves, your schema validates |
| org profile | dynamic-config | One engine, three languages, no daemon |

**Uploading** is per repository and web-only — Settings → *Social preview*
→ **Edit** → *Upload an image*:

- <https://github.com/dynamic-config-rs/dynamic-config/settings>
- <https://github.com/dynamic-config-rs/dynamic-config-remote/settings>
- <https://github.com/dynamic-config-rs/dynamic-config-python/settings>
- <https://github.com/dynamic-config-rs/dynamic-config-node/settings>
- <https://github.com/dynamic-config-rs/.github/settings> (the org card)

**Check:** paste a repository URL into any chat that unfurls links, or

```sh
curl -s https://github.com/dynamic-config-rs/dynamic-config \
  | grep -o '<meta property="og:image" content="[^"]*"' | head -1
```

The URL changes from `opengraph.githubassets.com/…` to
`repository-images.githubusercontent.com/…` once an image is set.

## 5. PyPI trusted publishing

**Why:** the wheels currently upload with `PYPI_TOKEN`. Trusted publishing
replaces it with OIDC — nothing to store, nothing to rotate, nothing to
leak — and PyPI shows a *Verified details* panel naming the repository and
workflow that built the release, which is the same signal npm already gets
from `--provenance`.

### 5.1 Tell PyPI which workflow may publish

For **each** of the two projects:

- <https://pypi.org/manage/project/dynamic-config-py/settings/publishing/>
- <https://pypi.org/manage/project/dynamic-config-py-remote/settings/publishing/>

Add a **GitHub** publisher:

| Field | Value |
|---|---|
| Owner | `dynamic-config-rs` |
| Repository name | `dynamic-config-python` |
| Workflow name | `release.yml` |
| Environment name | `pypi` |

The environment is optional to PyPI and worth setting anyway: it is a
second place to require a review before anything is uploaded.

### 5.2 Create the environment, and switch the job to OIDC

```sh
gh api -X PUT repos/dynamic-config-rs/dynamic-config-python/environments/pypi
```

Then, in `.github/workflows/release.yml`, the `publish-wheels` job. It
looks like this today:

```yaml
  publish-wheels:
    …
      - run: pip install maturin
      - run: maturin upload --skip-existing dist/*
        env:
          MATURIN_PYPI_TOKEN: ${{ secrets.PYPI_TOKEN }}
```

and becomes:

```yaml
  publish-wheels:
    …
    environment: pypi
    permissions:
      # The OIDC token PyPI verifies. Without this line the action has
      # nothing to present and falls back to looking for a password.
      id-token: write
    steps:
      …
      # `maturin upload` has no OIDC path; PyPA's action does, and it
      # uploads whatever is in the directory — which is what the wheel
      # jobs already downloaded.
      - uses: pypa/gh-action-pypi-publish@release/v1
        with:
          packages-dir: dist
          skip-existing: true
```

Pin that action by SHA like every other one in these workflows before
committing it.

### 5.3 Afterwards

- Delete `PYPI_TOKEN`:
  `gh secret delete PYPI_TOKEN --repo dynamic-config-rs/dynamic-config-python`
- The next release's PyPI page shows the *Verified details* panel. Until
  then nothing visible changes.

**One caveat:** trusted publishing is configured *per project*, and both
projects must be configured or the second upload fails alone. Do them in
the same sitting.

## 6. Search Console and Bing

Separate note, with the property type, the verification file and the
sitemap submission: **[`SEARCH-CONSOLE.md`](SEARCH-CONSOLE.md)**.

Short version: URL-prefix property for
`https://dynamic-config-rs.github.io/`, verify with the HTML file served
from the docs repository's `static/` directory, submit `sitemap.xml`, then
import the property into Bing Webmaster Tools in one click.

---

## Order to do them in

```text
1 crates.io e-mail        ← blocks the next release
2 Discussions             ← one command
3 Pins                    ← two minutes, biggest visual change
5 PyPI trusted publishing ← before the next wheel release, not after
6 Search Console          ← after the sitemap is live
4 Social previews         ← whenever there is an hour for the images
```
