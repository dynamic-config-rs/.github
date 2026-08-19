# Outstanding

State as of 2026-08-19, after the stabilisation round (the one that
zeroes CREDIBILITY-BACKLOG.md and the k8s ROADMAP): everything below is
either a queued user action or a thing that is true and should not stay
true. Nothing blocks anything.

## Where everything stands

| registry | package | published | next (this round, unreleased) |
|---|---|---|---|
| crates.io | `dynamic-config`, `-macros`, `-cli`, `-embedded` | 0.7.0 | 0.7.1 |
| crates.io | the ten store crates, `-store-core` … `-server` | 0.7.0 | patch wave |
| crates.io | `-web-core`, `-tower`, `-axum`, `-actix`, `-loco` | 0.2.0 | 0.2.x |
| PyPI | `dynamic-config-py`, `dynamic-config-py-remote` | 0.3.0 | 0.3.x |
| PyPI | `dynamic-config-py-web` | 0.2.0 | 0.2.x |
| npm | `dynamic-config-node`, `dynamic-config-node-remote` | 0.0.4 | 0.0.5 |
| ghcr + Docker Hub | the three k8s images + chart | 0.1.0 | 0.1.1 → 0.2.0 → 0.3.0 |

The docs site publishes seven books — `/`, `/remote/`, `/python/`,
`/node/`, `/web/` (Python web), `/rust-web/`, `/k8s/`.

## 0 — Queued user actions, post-train

In release-train order; none can be done by a working tree:

1. **PyPI + npm trusted publishing — the workflows are ALREADY
   token-free**, so these console entries must exist BEFORE the next
   python/node release or the publish step fails:
   - **PyPI** → each project → Settings → Publishing → *Add a trusted
     publisher* (GitHub): owner `dynamic-config-rs`, repository
     `dynamic-config-python`, workflow `release.yml`, environment blank —
     for **`dynamic-config-py`** and **`dynamic-config-py-remote`** —
     and the same entry on **`dynamic-config-py-web`** (repository
     `dynamic-config-python-web`, workflow `release.yml`).
     Afterwards both repos' `PYPI_TOKEN` secrets can be revoked.
   - **npm** → each package → Settings → *Trusted publisher* (GitHub
     Actions): repository `dynamic-config-rs/dynamic-config-node`,
     workflow `release.yml` — for the full roster:
     `dynamic-config-node`, `dynamic-config-node-remote`, and the ten
     platform packages `dynamic-config-node{,-remote}-linux-x64-glibc`,
     `…-linux-arm64-glibc`, `…-darwin-x64`, `…-darwin-arm64`,
     `…-win32-x64`. Afterwards `NPM_TOKEN` can be revoked and deleted.
   `--provenance` stays on for npm; PyPI attests through the same OIDC.
   SLSA beyond this is optional polish, no longer a queue item.
2. **Tag `.github` as `v1`** once its reusable workflows merge —
   `dynamic-config-remote/security.yml` (the migration pilot) points at
   `@main` and says exactly where to flip it.
3. **ArtifactHub claim** after k8s 0.1.1's first release lands the
   chart and metadata on ghcr (`deploy/helm/artifacthub-repo.yml`
   documents the claim; paste the repositoryID it assigns).
4. **Dependabot's `time` ignore** can come off wherever it was set: the
   1.88 floor took the real fix.
5. **The dev-only `[patch.crates-io]` blocks** in the python and node
   workspaces come OUT — and their engine floors go to `"0.7.1"` — in
   the same commit that releases each binding, after engine 0.7.1 is on
   crates.io. Both blocks say so in place; `cargo package` refuses
   patched sources, so forgetting is loud.

## 0b — The macOS setLogger silence, now with its un-skip gate

The two Node delivery tests skip on darwin (the engine goes silent for
a whole test process on macOS CI while Linux delivers everywhere; the
skip is loud and points here). The investigation's next move now runs
without a human: the node repository's **nightly `maclogger` leg** runs
those tests on a hosted `macos-14` runner with the skip lifted
(`DYNAMIC_CONFIG_MAC_LOGGER_GATE=1`). Reproduces → real on hosted
hardware, investigate there; passes → the silence narrows to the local
runner's FSEvents, and that fact gets recorded here. Either result
moves it; the skip alone never did.

## 1 — `CLAUDE_CODE_OAUTH_TOKEN` is missing on the two new repositories

The four older repositories have it. `dynamic-config-web` and
`dynamic-config-python-web` do not, so `claude.yml` fails in both the
moment anything triggers it.

```sh
for r in dynamic-config-web dynamic-config-python-web; do
  gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo dynamic-config-rs/$r
done
```

## 2 — Seven open Dependabot pull requests

Routine, all targeting `main`. Two want reading rather than merging:

- **`typescript 5.9.3 → 7.0.2`** in `dynamic-config-node`. A major, and the
  type gate runs against it.
- **`aws-sdk-s3`** in `dynamic-config-remote`, whose identity cache is
  already named in that repository's `security.yml`.

Separately, a Dependabot *update job* errored in `dynamic-config-remote`
(`cargo in /. for lru`). Its log needs repository write access to read.

## 3 — `actions/upload-artifact` is split across two majors

Eleven call sites on v4, two on v7. The v7 ones are inside the wheel and
addon publishing paths, which is why this was left alone during the release
round rather than changed underneath it. It is a single pull request now
that nothing is mid-flight.

## 4 — This directory is not under version control

`protect-branches.sh` and `prose-check.py` live here and nowhere else, so
the improvements made to the first during this round exist only on this
disk:

- it survives a repository in `REPOS` that has not been created yet, and one
  whose `main` has never been pushed, instead of aborting and silently
  leaving every repository after it unprotected;
- it skips a `dev` branch that does not exist yet.

**Still unwritten, and it cost a cycle on both new repositories:** the script
sets branch protection but not the *repository* settings that the release
flow depends on. `gh repo create` leaves them off, so a new repository
arrives with auto-merge disabled and `promote.sh` fails on
`enablePullRequestAutoMerge`. The block to add, inside the per-repository
loop:

```sh
gh api -X PATCH "repos/${ORG}/${repo}" --input - >/dev/null <<'JSON'
{
  "allow_auto_merge": true,
  "allow_squash_merge": true,
  "allow_rebase_merge": true,
  "allow_merge_commit": false,
  "delete_branch_on_merge": false,
  "squash_merge_commit_title": "COMMIT_OR_PR_TITLE",
  "squash_merge_commit_message": "COMMIT_MESSAGES"
}
JSON
```

Each value earns its place: `allow_auto_merge` is what `promote.sh` arms;
`allow_merge_commit: false` matches the linear-history rule that would
refuse one anyway; `delete_branch_on_merge` **must** stay false, because
`dev` outlives every merge; and `COMMIT_OR_PR_TITLE` is what makes the pull
request title become `main`'s commit subject, which is the whole reason
`promotion-title.sh` exists.

## Deliberately not done

- **`~/rust-project-templates/my-axum-template`** is outside the
  organisation and was left untouched. It depends on `dynamic-config` and
  has three sections with no HTTP wiring, so it is the honest end-to-end
  test of `dynamic-config-axum` — but it is not this organisation's code.
- **CI path filtering has never been observed doing its job.** The `changes`
  job and the per-job `if:` conditions are reasoned about and were exercised
  by every pull request this round, but nobody has watched a docs-only pull
  request skip the expensive jobs while `CI is green` still reports success.
  One such pull request would settle it.
