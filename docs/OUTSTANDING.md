# Outstanding

State as of 2026-08-18, after the release round that shipped
`dynamic-config-web` 0.1.0, `dynamic-config-py` 0.2.0,
`dynamic-config-py-web` 0.1.0 and `dynamic-config-node` 0.0.3.

Nothing here blocks anything. Each item is a thing that is true and should
not stay true.

## Where everything stands

| registry | package | version |
|---|---|---|
| crates.io | `dynamic-config`, `-macros`, `-cli`, `-embedded` | 0.6.3 |
| crates.io | the ten store crates, `-store-core` … `-server` | 0.6.2 |
| crates.io | `-web-core`, `-axum`, `-actix`, `-loco` | 0.1.0 |
| PyPI | `dynamic-config-py`, `dynamic-config-py-remote` | 0.2.0 |
| PyPI | `dynamic-config-py-web` | 0.1.0 |
| npm | `dynamic-config-node`, `dynamic-config-node-remote` | 0.0.3 |

All six repositories: working tree clean, `dev` level with `main`, CI and
Security green on `main`, `main` protected with `CI is green` +
`Security is green`, strict, admins included, linear history, no force
pushes or deletions.

The docs site publishes five books — `/`, `/web/`, `/remote/`, `/python/`,
`/node/`.

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


---

## Update — the perfection round (0.7 work, in progress on disk)

Everything above the line was the state after the release day. Since
then, on this disk and uncommitted: the 0.7 train (logging bridge +
ini/properties + `Format` non_exhaustive), the scope-tear fix and
conformance case 13, the route-table dedup, `dynamic-config-tower`, the
`/rust-web/` book, quickstarts and the two wall splits, this repository
(`.github`) assembled, node's msrv/docs CI jobs, coverage jobs, and the
one-shot scripts deleted (their repo-settings logic now lives in
`protect-branches.sh`). `ROADMAP.md` in the engine repo is the plan of
record; item 1 (CLAUDE_CODE_OAUTH_TOKEN) and the Dependabot PRs remain
open operator actions.

## setLogger delivery on macOS CI (dynamic-config-node)

On GitHub's macOS runners, the moment `tests/logging.test.js` runs, the
engine goes silent for that whole test process: no sink invocation, no
stderr fallback, no watch-driven reload (generation never advances) —
while the identical binary reloads and logs normally in the sibling
test processes of the same run, and Linux delivers everywhere. Bracket
diagnostics around the sink call printed nothing, so the stall is
upstream of the sink. The two delivery tests skip on darwin with a
pointer here; the sink itself gained `catch_unwind` and a loud
non-Ok-status fallback either way. Needs a session on real mac
hardware: reproduce `logging.test.js` alone, then bisect
setLogger-install → manual reload → watch reload.
