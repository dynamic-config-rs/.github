#!/usr/bin/env bash
# Whether every copy of a shared script still matches the canonical one
# here — the copies.rs pattern, applied twice.
#
#   ./scripts-drift.sh /path/to/checkouts-parent
#
# **Two sets, and they drift for different reasons.** The per-repo scripts
# are vendored into each repository so a contributor with one checkout can
# run them; they drift when a fix lands in one copy. The org-level scripts
# below sit beside the checkouts, where somebody runs them by hand against
# the whole organisation; they drift when that working copy is edited and
# the versioned one is not — which is the harder direction to notice,
# because the versioned copy is the one nobody looks at.
#
# Two scripts are NOT in the set, per-repo by design: `promotion-title.sh`
# (it knows where each repo's version lives) and `security-status.sh`
# (the pure-Python repository audits with OSV where the Rust ones use
# cargo-deny). A script missing from a repo is reported but not fatal —
# ci-local.sh exists in four of six.
set -euo pipefail

parent="${1:-..}"
here="$(cd "$(dirname "$0")" && pwd)"

. "${here}/repos.lib.sh"

drifted=0

for repo in $(repos_where dev true); do
  checkout="${parent}/${repo}"

  [ -d "${checkout}/scripts" ] || { echo "── ${repo}: no checkout at ${checkout}"; continue; }

  echo "── ${repo}"

  while IFS= read -r line; do
    wanted="${line%% *}"
    name="${line##* }"
    theirs="${checkout}/scripts/${name}"

    if [ ! -f "${theirs}" ]; then
      echo "   ${name}: absent"
      continue
    fi

    actual=$(sha256sum "${theirs}" | cut -d' ' -f1)

    if [ "${actual}" != "${wanted}" ]; then
      echo "   ${name}: DRIFTED"
      drifted=$((drifted + 1))
    fi
  done < "${here}/scripts-manifest.sha256"
done

# The org-level scripts: one copy here, one beside the checkouts.
#
# Not vendored into anything — these act on the organisation rather than on
# a repository, so there is nowhere else for them to live. The working copy
# is where they are run from and the copy here is the one that survives a
# disk, and the two have gone out of step before: `github-metadata.sh` in
# the working copy had lost the whole `dynamic-config-k8s` block, so a run
# of it silently left that repository without a description or topics.
ORG_LEVEL="repos.toml repos.lib.sh security-features.sh protect-branches.sh set-secrets.sh github-metadata.sh prose-check.py"

echo "── the organisation-level scripts"

for name in ${ORG_LEVEL}; do
  theirs="${parent}/${name}"

  if [ ! -f "${theirs}" ]; then
    echo "   ${name}: no working copy at ${theirs}"
    continue
  fi

  if ! cmp -s "${here}/${name}" "${theirs}"; then
    echo "   ${name}: DRIFTED"
    drifted=$((drifted + 1))
  fi
done

if [ "${drifted}" -gt 0 ]; then
  echo
  echo "${drifted} drifted copies. The canonical versions live here — the"
  echo "per-repo ones under ${here}/scripts, the org-level ones beside this"
  echo "script. Either carry the change into the canonical copy and update"
  echo "the manifest (a deliberate change), or re-copy over the drift."
  exit 1
fi

echo
echo "every vendored copy matches the canonical set"
