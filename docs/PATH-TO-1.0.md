# The path to 1.0

An operator note from an outside review, filtered: what is worth doing,
what it costs, and what was already true when the review was written. It
lives outside the five checkouts on purpose — the decisions that survive
belong in each repository's `ROADMAP.md` or book, not in a plan document
nobody updates.

**The rule this whole list serves:** between 0.6.1 and 1.0, only security
fixes and hotfixes land. Nothing below adds surface. Everything below adds
*evidence* that the surface is right.

---

## 1. A semantic conformance suite — the one that matters

One set of fixtures, three implementations, one expected answer.

```text
        conformance/fixtures/*.toml + expected.json
                /          |          \
             Rust       Python       Node
                \          |          /
                   byte-identical result
```

**Why it is the highest-value item.** The three bindings share an engine
but not a surface: precedence is resolved in Rust, but *what a caller
passes in* — a profile name, an env prefix, a `--set` assignment, an
override — is language-specific glue, and that glue is where the three can
silently disagree. Every drift found so far was found by hand.

**Shape.** A directory of cases, each a fixture set plus the resolved
document as JSON:

```text
conformance/
  cases/
    precedence-file-beats-default/
      config.toml
      env.json          # variables to set
      args.json         # --set pairs, overrides, profile
      expected.json     # the resolved document, exactly
    discovery-layers-every-match/
    secrets-dir-beats-file/
    env-typing-widens/
    profile-selects-a-variant/
    alias-accepts-another-spelling/
    unknown-key-is-reported-not-dropped/
    refused-document-leaves-previous-serving/
```

A runner per language, each ~50 lines: read the case, build the config,
compare `current()` to `expected.json`. In CI they run in all three, and a
disagreement names the case.

**Where it lives.** Its own repository (`dynamic-config-conformance`), so
none of the three depends on another; each pulls it as a git submodule or
a downloaded tarball in CI. A fifth repository is a real cost — the
alternative is keeping the fixtures in the engine's repository and having
Python and Node fetch them, which couples release timing less.

**Cost.** Two to three days for the harness and a first twenty cases;
after that a case is minutes.

## 2. Cross-language parity, documented as a table

Not everything *should* be identical — `initSync` exists in Python and
cannot exist in Node, and the reasons are already written down. What is
missing is one page that lists every surface and says *same / different /
absent, and why*, so a reader porting between them stops guessing.

Cheap (an afternoon), and it doubles as the specification the conformance
suite tests against.

## 3. Long-running evidence

- **Soak**: a watcher reloading every second for 24 hours, memory and file
  descriptors flat. `just shuttle-soak` covers the model; this covers the
  process.
- **Chaos, wider**: `just chaos` unplugs three stores. The other five have
  the same watch contract and no such test.
- **Fuzz, continuously**: `just fuzz` runs on demand and in CI; a nightly
  run with a persistent corpus finds different things.

Each is a workflow and a schedule, not new code.

## 4. Supply-chain hardening, the parts not done

- **PyPI Trusted Publishing** — token-free release and a "Verified
  details" badge on the project page.
- **npm Trusted Publishing** — same idea; needs each of the twelve
  packages configured once, so it is worth doing right after a release
  rather than before one.
- **Signed tags** for releases; `cargo-release` can be told to sign.
- **SLSA provenance** for the wheels, matching what npm already gets from
  `--provenance`.

## 5. Benchmarks somebody else can reproduce

The engine's numbers (85 instructions, zero allocations) are measured and
committed. What is missing is the *comparison* a reader actually wants:
against `config-rs`, against `figment` alone, against re-reading a file
per access. One page, honest numbers, both directions.

## 6. Adoption, which is not an engineering task

The review's sharpest point: there is no user-generated issue history yet,
and API problems surface between ten and a thousand users rather than in
review. Things that move that needle, roughly in order of effort:

- a "who is using this" discussion thread,
- a post that leads with the *combination* rather than the category —
  typed config + hot reload + last-known-good + remote stores + provenance
  + one engine behind three languages + no daemon,
- entries in `awesome-rust`, `awesome-python`, `awesome-nodejs`,
- answers to real questions on the fora where people ask them (r/rust,
  users.rust-lang.org, Stack Overflow's `configuration` tag).

---

## Already true when the review was written

Worth recording, so these do not get re-done:

- **Repository descriptions and topics** are set on all five repositories
  (19–20 topics on the engine, 16–19 elsewhere), plus the organisation's
  description and website. The review's suggested topic lists are subsets
  of what is there; four missing spellings (`config-management`, `rust`,
  `napi`, `configuration`) were added afterwards.
- **The multi-repository split** the review endorses is the shape that
  shipped, for the reason it gives: release coupling.
- **"Only security fixes and hotfixes until 1.0"** is already the
  documented policy, in every README, the org profile and the stability
  chapter.
- **Support tiers** are now on the organisation profile — a different axis
  from the stability tiers already in the book.

## Deliberately not doing

- **New language bindings** (Go, JNI, Ruby, PHP). The maintenance surface
  is already wide for one maintainer; a fourth binding before the third
  has users is how a project stops shipping.
- **A ninth store.** Same reason. `RemoteSource` is public and documented
  precisely so somebody else can write one without asking.
- **A monorepo again.** The split is doing what it was for: the churn
  lives with the client libraries, not with the engine.
