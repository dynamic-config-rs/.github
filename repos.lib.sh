#!/usr/bin/env bash
# Sourced by the org scripts: the reader for repos.toml's constrained
# subset. `repos` lists sections; `repo_get NAME KEY` answers a value,
# empty when absent.

REPOS_TOML="$(dirname "${BASH_SOURCE[0]}")/repos.toml"

repos() {
  awk -F'[][]' '/^\[/ { print $2 }' "$REPOS_TOML"
}

repos_where() {
  # repos_where gates true → every repo whose `gates` is `true`.
  local key="$1" want="$2"
  local repo
  for repo in $(repos); do
    [ "$(repo_get "$repo" "$key")" = "$want" ] && echo "$repo"
  done

  return 0
}

repo_get() {
  local repo="$1" key="$2"
  awk -v section="[$repo]" -v key="$2" '
    $0 == section          { here = 1; next }
    /^\[/                  { here = 0 }
    here && $1 == key      {
      # strip `key = `, quotes, and a trailing comment
      sub(/^[^=]*= */, ""); sub(/ *#.*$/, ""); gsub(/"/, "")
      print; exit
    }
  ' "$REPOS_TOML"
}
