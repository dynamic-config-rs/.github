#!/usr/bin/env bash
# Whether every repository's vendored copy of the shared scripts still
# matches the canonical set here — the copies.rs pattern, applied to the
# eight scripts that are meant to be byte-identical in all six repos.
#
#   ./scripts-drift.sh /path/to/checkouts-parent
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

if [ "${drifted}" -gt 0 ]; then
  echo
  echo "${drifted} drifted copies. Canonical versions live in ${here}/scripts;"
  echo "either update the manifest (a deliberate change) or re-copy (drift)."
  exit 1
fi

echo
echo "every vendored copy matches the canonical set"
