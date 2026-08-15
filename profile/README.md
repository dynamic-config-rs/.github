# dynamic-config

**One configuration engine, the same semantics in Rust, Python and
Node.js.** Files, environment, remote stores and command-line flags merged
into one typed value, re-read when they change, served to every thread as
a single atomic load — with hot reload, a last-known-good cache and
provenance for every value, and no daemon to run.

📖 **[The books](https://dynamic-config-rs.github.io/)** · one site, four
sections

---

## Start here

| If you write | Install | Book |
|---|---|---|
| **Rust** | `cargo add dynamic-config` | [dynamic-config-rs.github.io](https://dynamic-config-rs.github.io/) |
| **Python** | `pip install dynamic-config-py` | [/python/](https://dynamic-config-rs.github.io/python/) |
| **Node.js** | `npm install dynamic-config-node` | [/node/](https://dynamic-config-rs.github.io/node/) |
| **any of them, from etcd / Vault / S3 / …** | one crate, one extra, one package | [/remote/](https://dynamic-config-rs.github.io/remote/) |

```rust
#[dynamic_config]
#[derive(Debug, Deserialize)]
struct Database { host: String, port: u16 }

let builder = Database::builder("db").file("config.toml").env("APP_");
builder.init()?;                                     // load once, fail fast
builder.watch(Duration::from_millis(250))?.detach(); // and stay current

Database::current().host;                            // one atomic load, any thread
```

## What it is

- **Layered, with a stated order.** Defaults, discovered files, files,
  remote documents, `.env`, a secrets directory, the environment, bound
  variables, CLI assignments, overrides — each one wins over the last, and
  `explain()` says which layer supplied a value.
- **Hot reload that cannot corrupt.** A document the schema refuses
  installs nothing and leaves the previous one serving — from the watcher
  exactly as from an explicit reload.
- **Lock-free reads.** `current()` is an `arc-swap` guard: 85 instructions
  and zero allocations, measured by a benchmark rather than asserted.
- **Secrets are paths and types, never values.** Diffs, reports and error
  messages name the key and the expected type; the value stays out.
- **The same engine in three languages.** The bindings are thin: Rust
  resolves, your schema validates, and the host language reads a cache.

## The repositories

| Repository | Ships | Registry |
|---|---|---|
| [**dynamic-config**](https://github.com/dynamic-config-rs/dynamic-config) | the engine, `#[dynamic_config]`, the CLI, a `no_std` cell | [crates.io](https://crates.io/crates/dynamic-config) |
| [**dynamic-config-remote**](https://github.com/dynamic-config-rs/dynamic-config-remote) | etcd, Consul, Vault, NATS, Redis, S3, Firestore, git — and a config server | [crates.io](https://crates.io/crates/dynamic-config-etcd) |
| [**dynamic-config-python**](https://github.com/dynamic-config-rs/dynamic-config-python) | dataclasses, Pydantic, msgspec; asyncio; free-threaded builds | [PyPI](https://pypi.org/project/dynamic-config-py/) |
| [**dynamic-config-node**](https://github.com/dynamic-config-rs/dynamic-config-node) | Zod, Ajv or a plain function; prebuilt for five platforms | [npm](https://www.npmjs.com/package/dynamic-config-node) |

Each names the engine with a caret, so a patch release reaches it without
a release of its own — and each is released, tested and versioned in the
repository that owns it.

## Support tiers

Stability says *what a version bump may break*; a tier says *how much of
this we carry*. Everything below is Beta — these are two different axes.

| Tier | What | What it means |
|---|---|---|
| **1 — core** | `dynamic-config`, `dynamic-config-macros` | the compatibility promise everything else is measured against; the smallest dependency surface, and the last thing to change |
| **2 — official ecosystem** | `dynamic-config-remote`'s eight stores, the Python wheels, the npm packages, `dynamic-config-cli` | supported, released and tested on every change to the core; their dependency surface moves with their clients (AWS SDK, etcd, PyO3, napi), so most of the churn lives here |
| **3 — specialised** | `dynamic-config-embedded`, `dynamic-config-server` | narrower audiences, same gates, fewer callers to break; a change here is not a change to the engine |

## Stability

Every crate and package is **Beta**. Pre-1.0 a breaking change bumps the
minor version and a patch never breaks; **between here and 1.0 only
security fixes and hotfixes land**, so pinning the minor and taking
patches automatically is the intended way to depend on this.

That is a decision, not a pause: no new stores, no new language bindings
and no new surface until the current one has been used enough to know
what is wrong with it. What does happen before 1.0 is evidence —
conformance across the three languages, soak and chaos runs, fuzzing, and
whatever real use turns up.

## Contributing

Each repository carries its own `CONTRIBUTING.md`, its own gate
(`just check`) and its own book. Security reports go through the private
advisory form of the repository that owns the code — the address is in
each `SECURITY.md`.

<sub>MIT licensed. Released from `github.com/ctolon/dynamic-config` until
0.6.1, and from this organisation since.</sub>
