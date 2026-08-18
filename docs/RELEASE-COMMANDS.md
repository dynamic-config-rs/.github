# Release commands

What was actually run across the six repositories, and the traps each one
hides. Each repository's `RELEASING.md` is the authority on its own flow;
this is the cross-repository view, plus the diagnostics that were needed
when a step failed.

The model everywhere: work lands on `dev`, `main` accepts only pull requests
whose two gates passed, and **merging a version bump into `main` is the
release**. There is no tag to push by hand — `release.yml` runs on every
push to `main`, decides whether the version is new, and mints the tag itself.

## The order, and why it is an order

```
dynamic-config-web        no dependency beyond the published engine
dynamic-config-python     0.2.0 — must precede the line below
dynamic-config-python-web requires dynamic-config-py>=0.2
dynamic-config-node       independent
dynamic-config            promote only, [Unreleased] empty
dynamic-config-remote     promote only
dynamic-config-rs.github.io  last: it checks out all five book repositories
```

Two hard edges. `dynamic-config-py-web` declares `dynamic-config-py>=0.2`
and imports `ConfigGroup`, `Reloaded` and `ReloadFailed`, none of which
exist in 0.1.3 — so the engine ships first, and between the two publishes
`pip install dynamic-config-py[fastapi]` resolves to nothing. Run them back
to back. And the docs site must go last, because `site.yml` checks out
`dynamic-config-python-web`; pushing it before that repository existed would
have broken the six-hourly build.

## Cutting a release, per repository

**Rust workspaces** — `dynamic-config`, `dynamic-config-remote`,
`dynamic-config-web`. `cargo release` from `release.toml`; there is no
script.

```sh
just check
cargo release patch --execute        # or minor
cargo release 0.1.0 --execute        # a first release: names the version
git show --stat HEAD
```

The first release names the version explicitly because the manifests already
carry it and there is nothing to bump — what marks the release is the
changelog gaining the heading.

**Python** — `dynamic-config-python`.

```sh
./scripts/release-python.sh --status
./scripts/release-python.sh --check minor    # would it work?
./scripts/release-python.sh minor            # both wheels, both changelogs
```

**Python web** — `dynamic-config-python-web`.

```sh
./scripts/release-web.sh --check 0.1.0
./scripts/release-web.sh 0.1.0
```

`--check` takes the *target*, not the current version: a bare `--check`
reports the released version as taken, which says nothing about the release
being planned. It also refuses a `dynamic-config-py` floor PyPI cannot
satisfy, which is what caught the ordering above.

**Node** — `dynamic-config-node`. No script; three edits, not two.

```sh
sed -i 's/"version": "0.0.2"/"version": "0.0.3"/' \
  dynamic-config-node/package.json dynamic-config-node-remote/package.json
sed -i 's/"dynamic-config-node": "\^0.0.2"/"dynamic-config-node": "^0.0.3"/' \
  dynamic-config-node-remote/package.json
# then move each [Unreleased] block under `## 0.0.3 — <date>`
(cd dynamic-config-node && node --test tests/manifests.test.js)
```

The peer range is the third edit and the one that goes stale silently: npm's
caret pins the patch below 0.1.0, so `^0.0.2` names 0.0.2 **and nothing
else**. It was left at `^0.0.1` through the 0.0.2 release, which made the
matching pair refuse to install; `manifests.test.js` now fails when it
drifts.

## Promoting

Identical everywhere:

```sh
./scripts/promote.sh          # push dev → PR → arm auto-merge → wait → merge → resync dev
./scripts/watch-release.sh    # follow what the merge set off
./scripts/watch-ci.sh         # a run that is not a release
./scripts/propose.sh          # a pull request without the auto-merge wait
```

`promote.sh` **re-syncs `dev` onto `main` after the merge**, and that reset
discards anything uncommitted. Commit before running it.

## Bootstrapping a new repository

The order matters, and getting it wrong costs a cycle:

```sh
git init -b main
git add -A && git commit -m "…"

# --source=. pushes the CURRENT branch and makes it the default.
# Run it from main, or the repository's default branch becomes dev and
# promote.sh dies with "couldn't find remote ref main".
gh repo create dynamic-config-rs/<name> --public --source=. --remote=origin --push

git checkout -b dev && git push -u origin dev

# Neither of these is set by any script, and both are needed.
gh repo edit dynamic-config-rs/<name> --enable-auto-merge --enable-merge-commit=false
(cd .. && ./protect-branches.sh)

gh secret set PYPI_TOKEN --repo dynamic-config-rs/<name>          # or CARGO_REGISTRY_TOKEN
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo dynamic-config-rs/<name>
```

If `main` was created from a commit that is *not* a release, the push to
`main` still fires `release.yml`, and `verify` fails on the missing
changelog heading. To create `main` at a pre-release commit without a red
run, turn Actions off for the one push — `gh workflow disable` cannot help,
because a workflow that has never run is not registered:

```sh
gh api -X PUT repos/dynamic-config-rs/<name>/actions/permissions -F enabled=false
git push origin <sha>:refs/heads/main
gh api -X PUT repos/dynamic-config-rs/<name>/actions/permissions -F enabled=true
gh repo edit --default-branch main
```

## Verifying what is published

crates.io **answers 403 to a request with no `User-Agent`**. A release
workflow that omitted the header failed on it; so will an ad-hoc check.

```sh
UA='dynamic-config release (github.com/dynamic-config-rs)'
curl -sS -H "User-Agent: $UA" https://crates.io/api/v1/crates/dynamic-config-axum \
  | jq -r '.crate.max_version'

python -c "import json,urllib.request; \
  print(json.load(urllib.request.urlopen('https://pypi.org/pypi/dynamic-config-py/json'))['info']['version'])"

curl -sS https://registry.npmjs.org/dynamic-config-node | jq -r '.["dist-tags"].latest'
```

The claims each release makes, from the outside:

```sh
cargo add dynamic-config-loco                       # in a scratch project
pip install "dynamic-config-py[fastapi]"            # the extras chain resolves
pip install dynamic-config-py-web && python -c \
  "import sys, dynamic_config_web; print([m for m in sys.modules if m.startswith('fastapi')])"
npm install dynamic-config-node@0.0.3 dynamic-config-node-remote@0.0.3   # no ERESOLVE
```

## Diagnostics that were needed

**`promote.sh` stops after "ensuring the pull request exists".** It is
`set -euo pipefail` and something exited non-zero without printing. The two
causes seen: `origin` has no `main` branch, and `dev` is level with `main`
so `gh pr create` refuses. Both now print a sentence instead of dying.

```sh
git ls-remote --heads origin                 # does main exist?
git rev-list --count origin/main..HEAD       # is there anything to promote?
```

**Where a check actually failed**, without opening a browser:

```sh
gh pr checks <n> --repo dynamic-config-rs/<repo> | grep -v $'\tpass\t'
gh run view <run-id> --repo dynamic-config-rs/<repo> --log-failed --job <job-id>
gh run list --repo dynamic-config-rs/<repo> --workflow Release --limit 3 \
  --json conclusion,createdAt -q '.[] | "\(.conclusion) \(.createdAt)"'
```

**Reproducing a CI environment locally.** This is what caught the failures
that a developer machine hides — every framework installed is not the
environment CI builds:

```sh
python3 -m venv /tmp/row && /tmp/row/bin/pip install -e ".[test,ninja]"
/tmp/row/bin/python -m pytest tests/conformance/test_ninja.py -q --strict-markers

# mypy against an environment it is not installed in
mypy --strict --python-executable /tmp/bare/bin/python src/
```

**Rust release rehearsal**, closest thing to a real publish before the
bottom crate exists on the registry:

```sh
cargo publish -p <bottom-crate> --dry-run
cargo package --workspace --allow-dirty      # WITHOUT --no-verify: builds each tarball
cargo +nightly generate-lockfile -Z direct-minimal-versions
cargo +stable check --workspace --all-features --locked
cargo deny check
```

**Broken book anchors.** `lychee --include-fragments` finds these in CI one
repository at a time. mdBook maps *each* space to a hyphen and does not
collapse runs, so `name & paths` becomes `name--paths`; a checker that
collapses whitespace reports false positives. Build the book and grep the
generated HTML — that is authoritative:

```sh
mdbook build book
grep -o 'id="the-anchor-you-linked-to"' book/book/<page>.html
```

## Traps, one line each

- **crates.io 403 without a `User-Agent`** — and a step that treats
  "not 200 or 404" as fatal will stop there.
- **`excludes+=(--exclude "$crate")` adds two array elements**, so counting
  `${#excludes[@]}` is not counting crates.
- **`cargo check --all-targets` at an MSRV floor builds dev-dependencies**,
  which no user compiles; the engine's own job omits the flag on purpose.
- **`resolver.incompatible-rust-versions = "fallback"` applies at the
  *lowest* rust-version in the workspace.** Across 1.71 → 1.94 it held
  Loco's whole tree to 1.71 and pinned a vulnerable `lettre`.
- **Two examples with the same name in one workspace share an output
  filename**, and on Windows the parallel linkers race for the `.pdb`.
- **`gh repo create --source=.` makes the current branch the default.**
- **A local recipe weaker than CI is how a failure hides** — `just msrv`
  without `--all-targets`, `just types` running mypy once when CI runs it
  twice. Keep them identical.


---

## The 0.7 train (append-only update)

The order, with the new constraints the train adds:

1. **engine 0.7.0** — `cargo semver-checks` must report exactly one
   break (`Format` non_exhaustive). The changelog's ⚠️ entries are the
   release notes.
2. **python 0.7-aligned minor** — FIRST remove `[patch.crates-io]` from
   the workspace Cargo.toml and move the floor to `dynamic-config = "0.7"`;
   `release-python.sh --check` refuses while the patch is present, by
   design.
3. **node 0.7-aligned minor** — same patch removal, same guard in
   `scripts/release.sh`.
4. **web crates minor** — five now (`dynamic-config-tower` joined);
   release.yml's first wave is core → tower, then axum+actix, then loco.
5. **python-web minor** — the route-table refactor and the tear fix.
6. **remote** — dep-bump to engine 0.7 when convenient; nothing blocks.
7. Site last, as always. It builds six books now (`/rust-web/` is new).

Before any of it: create `dynamic-config-rs/.github` from `.github-repo/`
(see that repository's README), since the site and the caller migration
reference it.
