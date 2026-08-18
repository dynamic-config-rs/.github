# .github — the organisation's shared machinery

One repository holding everything that was either copied six times or
lived loose on one maintainer's disk:

| | |
|---|---|
| `profile/` | the organisation's GitHub profile page |
| `repos.toml` + `repos.lib.sh` | **the** repository registry — every script reads it; a new repository is added here, once |
| `protect-branches.sh` | branch protection **and** the repo settings the release flow needs (auto-merge on, merge commits off, `dev` survives merges) |
| `set-secrets.sh`, `security-features.sh`, `github-metadata.sh` | the other operator passes, all registry-driven |
| `scripts/` + `scripts-manifest.sha256` + `scripts-drift.sh` | the canonical copies of the seven byte-identical vendored scripts, and the check that the six repos' copies still match |
| `.github/workflows/reusable-*.yml` | `workflow_call` workflows: Rust security, book build + prose register, Rust coverage |
| `prose-check.py` | the banned-construction check the books are written against |
| `templates/migration-guide.md` | what every breaking release ships |
| `docs/` | the runbooks and standing plans (RELEASE-COMMANDS, PATH-TO-1.0, OUTSTANDING, …) |

## Migrating a repository onto the reusable workflows

Only after this repository exists on GitHub — a caller referencing
`dynamic-config-rs/.github/...@v1` fails while it does not. Then, one
repository at a time (start with `dynamic-config-remote`, the widest
matrix):

1. Replace the repo's `security.yml` deny/unsafe/supply-chain jobs with
   one job:
   ```yaml
   shared:
     uses: dynamic-config-rs/.github/.github/workflows/reusable-security-rust.yml@v1
     with:
       crates: "crate-a crate-b"
   ```
   **Keep the repo's own `security-ok` gate job** — branch protection
   requires the check *name*, and names stay local. Point its `needs` at
   `shared`.
2. Prove it with `workflow_dispatch` on a branch before merging.
3. Tag this repository `v1` and pin callers to the tag; a workflow change
   here then rolls out by moving the tag, deliberately.

## The drift check

```sh
./scripts-drift.sh /path/to/checkouts-parent
```

Red means a vendored copy moved without this repository agreeing. Two
scripts are per-repo by design and outside the set: `promotion-title.sh`
and (in the pure-Python repository) `security-status.sh`.
