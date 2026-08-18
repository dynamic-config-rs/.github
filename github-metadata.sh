#!/usr/bin/env bash
# What GitHub search, the organisation page and a link preview show.
#
# A description and a topic list are the only text GitHub's own search
# indexes for a repository, and the homepage field is what puts the book one
# click from the repository card. Topics are also how somebody browsing
# `topic:hot-reload` finds this at all — GitHub caps them at 20 and matches
# them exactly, so they are lower-case, hyphenated and specific.
#
# Safe to re-run: every call replaces the field wholesale.
set -euo pipefail

ORG=dynamic-config-rs
SITE=https://dynamic-config-rs.github.io

describe() {
  local repo="$1" homepage="$2" description="$3"
  gh repo edit "${ORG}/${repo}" --description "${description}" --homepage "${homepage}" >/dev/null
  echo "── ${repo}"
  echo "   ${description}"
}

topics() {
  local repo="$1"; shift
  # `--add-topic` is additive and there is no `--remove-all`, so the REST
  # call is the one that makes this idempotent.
  local list=""
  for topic in "$@"; do list="${list}\"${topic}\","; done
  gh api -X PUT "repos/${ORG}/${repo}/topics" \
    -H "Accept: application/vnd.github+json" \
    --input - >/dev/null <<JSON
{"names": [${list%,}]}
JSON
  echo "   topics: $*"
}

describe dynamic-config "${SITE}/" \
  "Hot-reloadable, lock-free configuration for Rust: one attribute declares the type, one builder states its sources — files, env, remote stores, live reload."
topics dynamic-config \
  config configuration configuration-management hot-reload live-reload \
  settings dotenv toml yaml json rust rust-crate figment serde \
  file-watcher twelve-factor no-std proc-macro cli config-management

describe dynamic-config-remote "${SITE}/remote/" \
  "Remote configuration stores for dynamic-config — etcd, Consul, Vault, NATS, Redis, S3, Firestore and git — plus a config server that serves sections over HTTP."
topics dynamic-config-remote \
  config configuration configuration-management remote-config hot-reload etcd consul \
  vault nats redis s3 firestore git config-server rust rust-crate \
  service-discovery kubernetes secrets-management

describe dynamic-config-python "${SITE}/python/" \
  "Hot-reloadable configuration for Python: Rust resolves, your schema validates — dataclasses, Pydantic or msgspec, with a watcher and a last-known-good cache."
topics dynamic-config-python \
  config configuration configuration-management hot-reload settings \
  python pydantic msgspec dataclasses pyo3 maturin rust-python \
  asyncio dotenv twelve-factor free-threading rust

describe dynamic-config-node "${SITE}/node/" \
  "Hot-reloadable configuration for Node.js: Rust resolves, your schema validates — Zod, Ajv or a function of your own, with a watcher that never blocks the loop."
topics dynamic-config-node \
  config configuration configuration-management hot-reload settings \
  nodejs typescript zod ajv napi-rs native-addon rust dotenv \
  twelve-factor express fastify napi

describe dynamic-config-web "${SITE}/rust-web/" \
  "One reading of configuration per request, for Rust web services: axum, Actix Web, Loco and plain tower — a snapshot layer and an extractor over dynamic-config."
topics dynamic-config-web \
  config configuration hot-reload rust rust-crate axum actix-web loco \
  tower middleware web request-scope dynamic-config

describe dynamic-config-python-web "${SITE}/web/" \
  "Web framework integrations for dynamic-config-py: FastAPI, Litestar, Flask, Quart, Django, DRF, django-ninja, Robyn and django-bolt — lifecycle, request scope, health and diagnostics."
topics dynamic-config-python-web \
  config configuration hot-reload python fastapi litestar flask quart \
  django django-rest-framework django-ninja asgi wsgi middleware

describe "${ORG}.github.io" "${SITE}/" \
  "The books of dynamic-config, built from five repositories and published as one site."
topics "${ORG}.github.io" \
  documentation mdbook github-pages config configuration hot-reload rust

echo
echo "── organisation"
# The organisation's own description and website: the first two lines of
# github.com/dynamic-config-rs, and what a search result shows.
gh api -X PATCH "orgs/${ORG}" \
  -f description="Hot-reloadable, layered configuration — one engine, four languages: Rust, remote stores, Python and Node.js." \
  -f blog="${SITE}/" >/dev/null
echo "   description and website set"

echo
echo "── coverage against repos.toml"
. "$(dirname "$0")/repos.lib.sh"
for repo in $(repos); do
  if ! grep -q "describe ${repo} \|describe \"\${ORG}.github.io\"" "$0" 2>/dev/null; then
    case "${repo}" in
      "${ORG}.github.io"|*.github.io) ;; # handled by the quoted describe above
      *) echo "   ::warning:: ${repo} is in repos.toml and has no describe block here" ;;
    esac
  fi
done

echo
echo "── what is set now"
for repo in dynamic-config dynamic-config-remote dynamic-config-python dynamic-config-node "${ORG}.github.io"; do
  gh api "repos/${ORG}/${repo}" \
    -q '"   \(.name): \(.topics | length) topics, homepage \(.homepage // "—")"'
done
