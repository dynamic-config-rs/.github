#!/usr/bin/env bash
# Branch protection for every repository in the organisation, in one pass.
#
# `main` is production: only pull requests, only with both gates green, only
# with a linear history, and admins are not exempt — the rule the old
# repository ran under, which is what made "the merge is the release" safe
# to say. `dev` gets the one rule it had there: it cannot be deleted.
#
# Safe to re-run: a PUT replaces the protection wholesale, so running this
# twice leaves exactly the same state.
set -euo pipefail

ORG=dynamic-config-rs
# The repository list lives in repos.toml — one file, every script. A
# repository added to the organisation and not to repos.toml has an
# unprotected `main`, which is the one failure this script exists to
# prevent — so the gap is also checked, below, against the live org.
. "$(dirname "$0")/repos.lib.sh"

REPOS=()
while IFS= read -r repo; do REPOS+=("$repo"); done < <(repos_where gates true)

# The two check names the workflows expose. They are job *names*, not job
# ids: "CI is green" is `ci-ok`'s name, "Security is green" is
# `security-ok`'s. A typo here is a branch nobody can merge into.
CHECKS='["CI is green", "Security is green"]'

for repo in "${REPOS[@]}"; do
  echo "── ${repo}"

  # A listed repository that does not exist yet, or one whose `main` has
  # never been pushed, has to be survivable rather than fatal: either sits
  # in the middle of the list, and dying on it would leave every repository
  # after it unprotected without ever saying so.
  if ! gh api "repos/${ORG}/${repo}" >/dev/null 2>&1; then
    echo "   not created on ${ORG} yet — skipped"
    continue
  fi

  if ! gh api "repos/${ORG}/${repo}/branches/main" >/dev/null 2>&1; then
    echo "   has no 'main' branch yet — skipped; push it and re-run"
    continue
  fi

  # Repository settings the release flow depends on and `gh repo create`
  # leaves off. This is the block whose absence cost a cycle on both new
  # repositories: promote.sh arms auto-merge, linear history refuses a
  # merge commit anyway, and `dev` must outlive every merge.
  gh repo edit "${ORG}/${repo}" \
    --enable-auto-merge \
    --enable-squash-merge \
    --enable-rebase-merge \
    --enable-merge-commit=false \
    --delete-branch-on-merge=false >/dev/null
  echo "   merges: auto-merge armed, squash and rebase only, dev survives"

  # main
  gh api -X PUT "repos/${ORG}/${repo}/branches/main/protection" --input - >/dev/null <<JSON
{
  "required_status_checks": { "strict": true, "contexts": ${CHECKS} },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "required_linear_history": true,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
  echo "   main: CI is green + Security is green, linear, conversations resolved, admins included"

  # dev — nothing required, because everything on dev is on its way to a
  # pull request anyway; what it must not do is disappear.
  if ! gh api "repos/${ORG}/${repo}/branches/dev" >/dev/null 2>&1; then
    echo "   dev: no such branch yet"
    continue
  fi

  gh api -X PUT "repos/${ORG}/${repo}/branches/dev/protection" --input - >/dev/null <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": true,
  "allow_deletions": false
}
JSON
  echo "   dev: force pushes allowed, deletion blocked"
done

# The docs site has no `dev` and no gates of its own: it builds from the
# other four and publishes. Deletion and force pushes are still worth
# blocking on the branch Pages deploys from.
echo "── ${ORG}.github.io"
gh api -X PUT "repos/${ORG}/${ORG}.github.io/branches/main/protection" --input - >/dev/null <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
echo "   main: linear, no force pushes, no deletion"

echo
echo "── what each repository ended up with"
for repo in "${REPOS[@]}" "${ORG}.github.io"; do
  printf '%-30s ' "${repo}"
  gh api "repos/${ORG}/${repo}/branches/main/protection" \
    -q '"main → checks: \(.required_status_checks.contexts // [] | join(", ") // "none")  admins: \(.enforce_admins.enabled)  linear: \(.required_linear_history.enabled)"' \
    2>/dev/null || echo "main → not protected"
done

# Anything with a CI gate that this script does not protect. A repository
# reaches production through `main`, and one whose `main` takes direct
# pushes is not protected by any of the above.
echo
echo "── repositories in ${ORG} that this script does not cover"

gh repo list "${ORG}" --limit 100 --json name,isArchived \
  --jq '.[] | select(.isArchived | not) | .name' |
  while read -r found; do
    case " ${REPOS[*]} " in
      *" ${found} "*) ;;
      *)
        if gh api "repos/${ORG}/${found}/contents/.github/workflows/ci.yml" >/dev/null 2>&1; then
          echo "   ${found} has a CI gate and is NOT in repos.toml"
        else
          echo "   ${found} (no ci.yml — nothing to require)"
        fi
        ;;
    esac
  done
