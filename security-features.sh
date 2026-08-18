#!/usr/bin/env bash
# Dependabot alerts and security updates, per repository.
#
# There is no organisation-wide toggle to look for: on a **public**
# repository GitHub builds the dependency graph itself — which is what
# dependency review needs — and it appears a few minutes after the first
# push rather than immediately. That is why the job failed on the repository
# pushed last and passed on the one pushed first.
#
# What is *not* automatic is Dependabot's two features, and those have REST
# endpoints, so they are here rather than in a settings page.
#
# Safe to re-run.
set -euo pipefail

ORG=dynamic-config-rs
. "$(dirname "$0")/repos.lib.sh"

for repo in $(repos_where gates true); do
  echo "── ${repo}"

  visibility=$(gh api "repos/${ORG}/${repo}" -q .visibility)
  if [ "${visibility}" != "public" ]; then
    echo "   ::warning:: ${repo} is ${visibility}; the dependency graph, Scorecard and the docs site all need it public"
  fi

  gh api -X PUT "repos/${ORG}/${repo}/vulnerability-alerts" >/dev/null
  echo "   Dependabot alerts: on"

  gh api -X PUT "repos/${ORG}/${repo}/automated-security-fixes" >/dev/null
  echo "   Dependabot security updates: on"

  if gh api "repos/${ORG}/${repo}/dependency-graph/sbom" >/dev/null 2>&1; then
    echo "   dependency graph: indexed — dependency review can run"
  else
    echo "   dependency graph: not indexed yet — rerun the Security workflow in a few minutes"
  fi
done
