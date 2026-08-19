# Roadmap

The plan of record for the whole organisation, kept beside the registry
and the runbooks it sequences. Each repository's own `ROADMAP.md` keeps
its crate-level decisions; this file keeps the milestones that cross
them.
Finished milestones stay listed: a roadmap that deletes its past is a
roadmap nobody can audit.

## The one-time amendment, said out loud

`PATH-TO-1.0.md` set a freeze: between 0.6.1 and 1.0, only security
fixes and hotfixes; everything else adds *evidence*, not surface. **The
0.7 round amends that once**, for three things that could not honestly
wait: a diagnostics story the wheels and addons need (`set_log_sink` and
the `logging` bridge), a `Format` enum that must break once so every
later format is additive, and the Kubernetes integration the ecosystem
expects of a configuration project. After 0.7, the freeze re-arms and
the 1.0 items below become the gate again.

## Milestones

### M1 — hotfix wave · ✅ built
The scope tear fixed in the Python request scope (with the conformance
case that would have caught it), the Node hook-delivery contract proven,
the missing tests everywhere, the stale prose corrected, the release
toil scripted (`repos.toml`, node's `release.sh`).

### M2 — the 0.7 train · ✅ SHIPPED 2026-08-18 (engine 0.7.0, stores 0.7.0, py 0.3.0, node 0.0.4)
Engine 0.7.0: the logging seam (sink, level, `log` feature — stderr
byte-identical by default), `Format` `#[non_exhaustive]` + `Ini` +
`Properties` (no new dependency, 1.71 floor held), the first migration
guide. Python: the `logging` bridge on by default,
`configure_logging()`. Node: `setLogger` opt-in. Bindings re-release
once, floors moved to 0.7, the `[patch.crates-io]` guards lifted as a
release step.

### M3 — integration round · ✅ SHIPPED 2026-08-18 (web 0.2.0 with tower, py-web 0.2.0)
python-web's route table (six adapters, one definition; conventions
preserved), `dynamic-config-tower` (the layer for tonic/hyper/any tower
stack), the long-lived-connection story told on both sides, the node
store module split, the `_config.py` no-split decision recorded.

### M4 — docs round · ✅ SHIPPED 2026-08-18 (seven books live, /rust-web/ and /k8s/ included)
Quickstarts in every book; the 477-line intro and the 991-line stores
page split; the config server un-gated; the `/rust-web/` book (eleven
pages, production-surface recipes); the parity table; `prose-check`
clean at zero across six books.

### M5 — devops round · ✅ SHIPPED 2026-08-18 (.github live; reusable-workflow caller migration is the follow-up)
The `.github` repository assembled: the registry (`repos.toml`) behind
every operator script, repo settings joined branch protection, the
scripts-drift checker (already caught the one real drift), three
reusable workflows, the migration-guide template. Per-repo: node gained
msrv/docs CI jobs (two floors, measured), web and python-web gained
coverage jobs. Caller migration is deliberately *after* the .github repo
exists on GitHub — the runbook is that repository's README.

### M6 — dynamic-config-k8s · in progress
The agent-injector shape, staged shippable: **6a** `dynamic-config-agent`
(init/sidecar binary rendering remote stores to files — any format,
`.properties` included, which is what M2 built it for), images to
ghcr.io and Docker Hub, the server image from the remote repository;
**6b** the mutating webhook, annotations-only, cert-manager required;
**6c** the operator (`DynamicConfigClass`, `DynamicConfigRender`). kind
e2e: smoke on PR, the full matrix nightly.

### M7 — 1.0 evidence (PATH-TO-1.0, unfrozen items only)
The cross-language conformance suite (fixtures in this repository —
M2's cross-format fixtures are its seed); soak and chaos coverage for
all eight stores; trusted publishing and SLSA for wheels and packages
(images sign from M6 day one); comparative benchmarks; the adoption
motions, led by the k8s integration.

### M8 — 1.0
Engine, bindings, web crates, python-web, remote — together.
`dynamic-config-k8s` stays 0.x until the operator has soak history, and
says so in its own book.

## Standing rules that outlive any milestone

- Merging a version bump into `main` **is** the release; tags are
  outputs.
- Every breaking release ships a migration guide from the template.
- A new repository starts in `repos.toml`, or it does not start.
- The books are written against `prose-check.py`, and the drift gates
  (`doc_surface`, `copies.rs`, `manifests.test.js`, `scripts-drift.sh`)
  are added *with* the duplication they police, never later.
