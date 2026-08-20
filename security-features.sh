#!/usr/bin/env bash
# Dependabot alerts, security updates and secret scanning, per repository.
#
# There is no organisation-wide toggle to look for: on a **public**
# repository GitHub builds the dependency graph itself — which is what
# dependency review needs — and it appears a few minutes after the first
# push rather than immediately. That is why the job failed on the repository
# pushed last and passed on the one pushed first.
#
# What is *not* automatic is Dependabot's two features and secret scanning,
# and all of them have REST endpoints, so they are here rather than in a
# settings page.
#
# **Push protection is the half that matters.** Secret scanning finds a
# credential after it has been pushed, which means after it has been
# published — the remedy is then revocation, not deletion, because the
# object is in every clone and in GitHub's event feed. Push protection
# refuses the push instead, which is the only point at which a leak is
# still a near miss.
#
# Safe to re-run.
set -euo pipefail

ORG=dynamic-config-rs
. "$(dirname "$0")/repos.lib.sh"

for repo in $(repos); do
  echo "── ${repo}"

  visibility=$(gh api "repos/${ORG}/${repo}" -q .visibility)
  if [ "${visibility}" != "public" ]; then
    echo "   ::warning:: ${repo} is ${visibility}; the dependency graph, Scorecard and the docs site all need it public"
  fi

  # Dependabot is for the repositories that build something. Secret
  # scanning, below, is for all of them: a credential pushed to the docs
  # site is as published as one pushed to the engine.
  if [ "$(repo_get "${repo}" gates)" = "true" ]; then
    gh api -X PUT "repos/${ORG}/${repo}/vulnerability-alerts" >/dev/null
    echo "   Dependabot alerts: on"

    gh api -X PUT "repos/${ORG}/${repo}/automated-security-fixes" >/dev/null
    echo "   Dependabot security updates: on"
  fi

  # Free on a public repository, and off by default on one that existed
  # before the feature did — which is why this is a loop rather than a
  # thing somebody remembered once.
  if gh api -X PATCH "repos/${ORG}/${repo}" \
       -f 'security_and_analysis[secret_scanning][status]=enabled' \
       -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' \
       >/dev/null 2>&1; then
    echo "   secret scanning + push protection: on"
  else
    echo "   ::warning:: ${repo}: secret scanning could not be enabled (private repository without GitHub Advanced Security?)"
  fi

  state=$(gh api "repos/${ORG}/${repo}" \
    -q '.security_and_analysis.secret_scanning.status + "/" + .security_and_analysis.secret_scanning_push_protection.status' 2>/dev/null || echo "unknown/unknown")
  echo "   secret scanning reports: ${state}"

  if [ "$(repo_get "${repo}" gates)" = "true" ]; then
    if gh api "repos/${ORG}/${repo}/dependency-graph/sbom" >/dev/null 2>&1; then
      echo "   dependency graph: indexed — dependency review can run"
    else
      echo "   dependency graph: not indexed yet — rerun the Security workflow in a few minutes"
    fi
  fi
done
