#!/usr/bin/env bash
# Every secret the five repositories need, asked for once and written where
# it belongs.
#
# How a value gets in: this prompts for it, with the terminal echo off, and
# hands it to `gh secret set --body`. Nothing is written to disk, nothing
# reaches your shell history, and an empty answer skips that secret — so
# you can run this now for the tokens you have and again for the rest.
#
#   ./set-secrets.sh
#
# Where each one goes, and why:
#
#   CLAUDE_CODE_OAUTH_TOKEN   every code repository — `claude.yml`
#                             answers `@claude` on a pull request
#   CARGO_REGISTRY_TOKEN      every crates.io repository — in the
#                             `crates-io` *environment*, not at repository
#                             level: that is the only place `release.yml`
#                             reads it from, and an environment is a second
#                             place to require a review before a publish
#   PYPI_TOKEN                the PyPI repositories
#   NPM_TOKEN                 dynamic-config-node — a granular token, *read
#                             and write on all packages*, with bypass-2FA on
set -euo pipefail

ORG=dynamic-config-rs
# The repository list and what each holds live in repos.toml — one file,
# every script. A new repository is added there, not here.
. "$(dirname "$0")/repos.lib.sh"

ask() {
  local name="$1" value
  printf '%s (blank to skip): ' "${name}" >&2
  read -rs value
  printf '\n' >&2
  printf '%s' "${value}"
}

set_repo_secret() {
  local name="$1" value="$2" repo="$3"
  [ -z "${value}" ] && return 0
  gh secret set "${name}" --repo "${ORG}/${repo}" --body "${value}"
  echo "   ${repo}: ${name}"
}

set_env_secret() {
  local name="$1" value="$2" repo="$3" environment="$4"
  [ -z "${value}" ] && return 0
  # The environment has to exist before a secret can live in it.
  gh api -X PUT "repos/${ORG}/${repo}/environments/${environment}" >/dev/null
  gh secret set "${name}" --repo "${ORG}/${repo}" --env "${environment}" --body "${value}"
  echo "   ${repo}: ${name} (environment ${environment})"
}

claude=$(ask "CLAUDE_CODE_OAUTH_TOKEN")
cargo=$(ask "CARGO_REGISTRY_TOKEN  (crates.io)")
pypi=$(ask "PYPI_TOKEN            (PyPI, both wheels)")
npm=$(ask "NPM_TOKEN             (npm, granular + bypass 2FA)")

echo
echo "── writing"
for repo in $(repos); do
  wanted=$(repo_get "${repo}" secrets)

  case ",${wanted}," in *",CLAUDE_CODE_OAUTH_TOKEN,"*)
    set_repo_secret CLAUDE_CODE_OAUTH_TOKEN "${claude}" "${repo}" ;;
  esac
  case ",${wanted}," in *",PYPI_TOKEN,"*)
    set_repo_secret PYPI_TOKEN "${pypi}" "${repo}" ;;
  esac
  case ",${wanted}," in *",NPM_TOKEN,"*)
    set_repo_secret NPM_TOKEN "${npm}" "${repo}" ;;
  esac

  if [ "$(repo_get "${repo}" environments)" = "crates-io" ]; then
    set_env_secret CARGO_REGISTRY_TOKEN "${cargo}" "${repo}" crates-io
  fi
done

echo
echo "── what each repository holds now"
for repo in $(repos_where gates true); do
  printf '%-24s repo: %-28s' "${repo}" "$(gh secret list --repo "${ORG}/${repo}" 2>/dev/null | cut -f1 | tr '\n' ' ')"
  printf 'crates-io: %s\n' "$(gh secret list --repo "${ORG}/${repo}" --env crates-io 2>/dev/null | cut -f1 | tr '\n' ' ')"
done
