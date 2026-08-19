# The credibility backlog

An external review (Codex, 2026-08) was run against the project and
produced thirty improvement points and a 1.0 ordering. This file is
that review **filtered against the repository's actual state after the
0.7 train** — the review looked at a pre-train snapshot (engine 0.6.3,
python 0.2.0, node 0.0.3), so a third of its asks were already shipped
or already written down. What survives the filter is curated here; what
does not, is recorded with the reason, so the next reviewer does not
re-litigate it.

The review's best sentence stands as the file's thesis: *the project
has a credibility backlog, not a feature backlog.* Everything below is
evidence-production, not surface.

---

## Already answered — do not re-open

| The review asked for | Where it already lives |
|---|---|
| API freeze before 1.0, stabilisation-not-features | Declared policy: 0.7 was the LAST surface round; the freeze is re-armed (`.github/docs/ROADMAP.md`, engine book) |
| Loom / model checking on the concurrency core | `dynamic-config/tests/loom.rs` + `shuttle.rs`; the web-core seqlock has deterministic + adversarial (fix-disabled) proofs |
| Fuzzing the parse path | Six targets live (`dotenv`, `flat_formats`, `redaction`, `sections`, `units`, `value_paths`), 1.37M execs on record — the *merge-invariant* targets are the real gap, adopted below |
| Transactional multi-config updates | `ConfigGroup.reload_atomic()` shipped in python 0.2 / node 0.0.3; adopted below: the one-sentence doc rule it still needs |
| Revision / generation / loaded-at on snapshots | `generation` and `loaded_at` exist (`reload.rs` health surface); needs surfacing in docs, not API |
| Slow-subscriber semantics | Node ships `latest / serial / every` backpressure modes; adopted below: the cross-language contract page |
| Supply-chain: deny/audit/pinned SHAs/dependabot/scorecard/SBOM | In place org-wide; the not-done parts (trusted publishing, SLSA attestations on all three registries) are PATH-TO-1.0 §4 |
| Cross-language golden parity, soak evidence, reproducible benchmarks, adoption | PATH-TO-1.0 §1, §3, §5, §6 — the review independently reinvented the same skeleton, which is a good sign for the skeleton |
| Pre-fork / Gunicorn multi-process documentation | Shipped with python 0.2.0 |
| Structured errors (source, path, kind, action taken) | Largely exists (scrubbed reports, `Refusal`, keep-last-good notices); a UX pass is folded into the cookbook item below |

## Adopted — the backlog itself

### P0 — evidence the engine's claims are load-bearing

1. ✅ **Secrets-dir containment contract + adversarial suite.** *(landed: follow-inside-only default + `allow_external_symlinks` opt-out, reads through the verified target, four adversarial tests beside the kubelet fixture; engine 0.7.1)* The
   loader *deliberately follows symlinks* (`loader/secrets.rs`) because
   the kubelet's `..data` projection is a symlink farm — which is
   exactly why a symlink pointing *outside* the secrets dir needs a
   written answer. Pydantic Settings shipped a CVE for this shape in
   June 2026. Decide the boundary (follow inside the mount, refuse
   escapes? refuse nothing but document?), write it in the book, then
   pin it with tests: escape via symlink, escape via `..`, TOCTOU
   swap mid-read. Cheap, high-credibility, directly regression-guarded.
2. ✅ **Merge/precedence property targets.** *(landed: `merge_laws`, `provenance_winner`, `lkg_serves_previous` fuzz targets, ≥1M execs each — the third found and fixed a real serde value-leak on its first corpus run)* Extend the fuzz corpus with
   invariants, not just parsers: `merge(A, ∅) = A`; an overlay changes
   values *only* at overlapping paths; `provenance(path)` names the
   source that supplied the winning value; valid-A-then-invalid-B
   always serves A. These are properties over generated layer stacks —
   the combinatorial edge-cases the review is right to fear.
3. ✅ **The failed-reload wake channel.** *(landed: same `Notify` + outcome counters, `events()`/`on_reload_failed`/`Event` additive, `changes()` untouched, two loom models; both bindings deliver natively and their polling workarounds retired)* Both bindings honestly document
   the same engine gap: a failed reload does not bump the generation,
   so `changes()` cannot wake a subscriber who wants to *see* the
   failure; status polling is the workaround. One core semantic
   addition (a second wake path or a generation-with-outcome), designed
   under the freeze rules — this is the single API question worth
   opening before 1.0-rc.
4. ✅ **The soak-and-leak rig.** *(landed: `soak/` workspace member, 5h nightly + `just soak-24h`, leak budgets engine+python+node, remote container legs)* PATH-TO-1.0 §3, concretized to the
   review's schedule: nightly job, 24h — N readers, writers,
   subscribers, remote sources; a fault script (malformed change,
   delete/restore, network cut/recover, auth expiry, watch-stream
   kill); invariants asserted at the end: no crash, no deadlock,
   bounded RSS/threads/FDs, LKG always valid, monotonic generations.
   Beside it, the leak budget: 1M reloads, then RSS / Arc counts /
   subscriber counts / FDs compared to start. Run the binding variants
   too — the python/node callback lifecycles are where leaks hide (the
   free-threaded finalization segfault this train fixed is the
   argument).
5. ✅ **The compatibility contract, published.** *(landed: `book/src/compatibility.md`, linked from all eight READMEs)* One page, engine book:
   what 1.x guarantees. Source-compatible minors; precedence order can
   never silently change; reload-failure semantics (LKG) can never
   silently change; `Origin`/provenance semantics stable; feature
   flags additive-only. The freeze policy exists — this is the
   *user-facing promise* the freeze buys, and it is worth more than
   any feature.

### P1 — contracts and cookbooks

6. ✅ **`changes()`/events semantics, formalized.** *(landed: engine book Change Notification page, canonical; binding books link)* One table, all three
   languages: edge- vs level-triggered, lossless vs coalescing, what a
   slow consumer sees (node's three modes are the vocabulary; python
   and rust state their positions in the same terms).
7. ✅ **The metrics contract.** *(landed: engine book page, names/labels/cardinality/hard rules)* A standard schema
   (`dynamic_config_reload_total`, `_reload_failed_total`,
   `_last_success_timestamp`, `_generation`, `_source_up`,
   `_snapshot_age_seconds`, `_watch_running`), labels bounded to
   `config` and `source`, an explicit cardinality note, and the hard
   rule: no values, no user paths, no secrets in labels. Documented
   first; exporters ride the existing health surfaces.
8. ✅ **Readiness semantics, written down.** *(landed: engine book page; web + py-web link)* The review's position is
   the right one and matches the engine's soul: LKG usable → ready;
   remote degraded → ready *with* a DEGRADED detail. One page shared
   by the server, python-web and k8s books.
9. ✅ **Schema-migration pattern page.** *(landed: engine book)* No migration engine — the
   library's deserialize-fails→LKG answer is correct. What is missing
   is the choreography doc: `schema_version` field pattern, consumer
   accepts V1+V2 → producer switches → consumer drops V1. One page,
   engine book, cross-linked from the stores.
10. ✅ **Explain as a contract.** *(landed: engine book page; `Explanation` is the stable type — rows public, Debug value-free, `redacted()`)* The CLI's explain shows the winner;
    promote the full resolution table (every layer, winner marked,
    absent layers named) to a documented, stable output — API
    formalization decided under freeze rules, doc-first.
11. ✅ **Secret lifecycle threat model.** *(landed: engine book Secret Lifecycle page, honest zeroization boundary included)* From store to `Arc` snapshot:
    how many copies, when old snapshots drop, what rotation leaves in
    memory, and the honest zeroization boundary (with `Arc<T>` and
    arbitrary user structs, full zeroize is not promisable — say so,
    state what IS promised: no Debug/Display/Error/diff/log leakage,
    already test-pinned; add the fuzz-level check from item 2's
    redaction target).
12. ✅ **The Kubernetes *guide* the review wanted alongside the injector
    we built anyway**: ConfigMap → projected volume → file watcher,
    kubelet symlink-replacement semantics (`..data`), atomic-writer
    behaviour, watch compatibility. The `secrets.rs` comments already
    know this; make it a book page. (The injector/operator
    disagreement is recorded below.)
13. ✅ **Production cookbook, end-to-end.** *(landed: web cookbook, k8s full-stack page, py-web production FastAPI, gunicorn reality in bold with a runnable three-file recipe)* One worked deployment per
    audience: axum + vault + prometheus + graceful shutdown;
    kubernetes + configmap/secret + readiness + metrics; FastAPI +
    shared executor + lifespan shutdown; the gunicorn multi-process
    reality (4 workers = 4 engines = 4 watches) stated in bold.
    Rust-web's production-surface page is the seed.
14. ✅ **Benchmarks with rivals, and a budget.** *(landed: benches/matrix.rs, benches-rivals vs config-rs/figment, performance-budget page, dependency-weight table)* The matrix (startup ×
    field-count, merge × layer-count, reload × file-size, readers ×
    1..128, watch × config-count) against config-rs, Figment, Viper,
    Koanf, Dynaconf, pydantic-settings — cross-language numbers
    labelled as architectural cost, not a race. Beside it the
    regression budget (`current()` ≤ baseline+5%, allocations/read = 0,
    compile-time and binary-size monitored) and the per-feature
    dependency-weight report (crate count, compile time, MSRV — the
    MSRV half already exists).
15. ⏳ **The independent audit.** *(unblocked: items 1–5 landed; scheduling is a user action)* Scope exactly as the review lists:
    core, server, vault integration, secret handling, both FFI
    layers. Scheduled after items 1–5 land — an audit of a codebase
    mid-evidence-production wastes the auditor.

### P2 — deferred, on the record

- **Go binding** — agreed rejection: Viper/Koanf serve Go natively;
  the Rust-engine advantage that justifies the Python/Node bindings
  (GIL-free watching, real threads) mostly evaporates in Go.
- **AWS AppConfig / Azure App Configuration / GCP SM** — demand-gated,
  per the standing "no store nobody asked for" rule.
- **Management UI, plugin framework, config DSL, embedded OTel SDK** —
  the never-list stands.
- **SourceRevision normalization** (etcd revision / ETag / commit SHA
  under one type) — API risk; the doc-table comparing per-store
  ordering/duplicates/consistency comes first (remote book already
  seeds it).

## One recorded disagreement

The review says the Kubernetes operator/webhook is scope creep and
would make the project "a configuration platform". The organisation
decided otherwise, with eyes open, and shipped the injector
(`dynamic-config-k8s`): the agent-injector shape was judged the
adoption surface Kubernetes users actually reach for. The warning is
kept as a *guard*, not a verdict: the operator stays thin (two CRDs,
reconcile-to-ConfigMap, nothing more), every extension is
demand-gated, and the moment the k8s repo starts growing platform
ambitions this paragraph is the tripwire.

## The order of work

The review's top-ten, re-cut against what already exists:

1. Compatibility contract page (P0.5 — days, highest leverage/word)
2. Secrets-dir containment contract + adversarial suite
3. Merge/precedence property fuzzing
4. Failed-reload wake design (the one pre-1.0 API question)
5. Soak-and-leak rig, nightly
6. Tri-language golden parity suite (PATH-TO-1.0 §1, already specced)
7. changes()/metrics/readiness contract pages (items 6–8 together)
8. Secret threat model + schema-migration + k8s-guide pages
9. Benchmark matrix + budgets
10. Independent audit, then 1.0-rc and the two-quiet-months freeze

Feature work during all of this: security fixes, bug fixes, and the
k8s repository's own ROADMAP. Nothing else.
