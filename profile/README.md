# dynamic-config

**One configuration engine, the same semantics in Rust, Python and
Node.js.** Files, environment, remote stores and command-line flags merged
into one typed value, re-read when they change, served to every thread as
a single atomic load — with hot reload, a last-known-good cache and
provenance for every value, and no daemon to run.

📖 **[The books](https://dynamic-config-rs.github.io/)** · one site, seven
sections

---

## Start here

| If you write | Install | Book |
|---|---|---|
| **Rust** | `cargo add dynamic-config` | [dynamic-config-rs.github.io](https://dynamic-config-rs.github.io/) |
| **Python** | `pip install dynamic-config-py` | [/python/](https://dynamic-config-rs.github.io/python/) |
| **Node.js** | `npm install dynamic-config-node` | [/node/](https://dynamic-config-rs.github.io/node/) |
| **a Python web service** | `pip install "dynamic-config-py[fastapi]"` | [/web/](https://dynamic-config-rs.github.io/web/) |
| **a Rust web service** | `cargo add dynamic-config-axum` | [/rust-web/](https://dynamic-config-rs.github.io/rust-web/) |
| **any of them, from etcd / Vault / S3 / …** | one crate, one extra, one package | [/remote/](https://dynamic-config-rs.github.io/remote/) |
| **pods on Kubernetes** | annotate the pod; an agent appears in it | [/k8s/](https://dynamic-config-rs.github.io/k8s/) |

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
| [**dynamic-config-python-web**](https://github.com/dynamic-config-rs/dynamic-config-python-web) | FastAPI, Litestar, Flask, Quart, Django + DRF + Ninja, Robyn, django-bolt — one behavioural contract | [PyPI](https://pypi.org/project/dynamic-config-py-web/) |
| [**dynamic-config-web**](https://github.com/dynamic-config-rs/dynamic-config-web) | tower, axum, Actix Web and Loco: one reading of configuration per request, however many sections a handler touches | [crates.io](https://crates.io/crates/dynamic-config-axum) |
| [**dynamic-config-k8s**](https://github.com/dynamic-config-rs/dynamic-config-k8s) | the agent-injector shape: annotate a pod and an agent renders any store to a file inside it — webhook, agent, operator | [ghcr.io](https://github.com/orgs/dynamic-config-rs/packages) |

Each names the engine with a caret, so a patch release reaches it without
a release of its own — and each is released, tested and versioned in the
repository that owns it.

## Support tiers

Stability says *what a version bump may break*; a tier says *how much of
this we carry*. Everything below is Beta — these are two different axes.

| Tier | What | What it means |
|---|---|---|
| **1 — core** | `dynamic-config`, `dynamic-config-macros` | the compatibility promise everything else is measured against; the smallest dependency surface, and the last thing to change |
| **2 — official ecosystem** | `dynamic-config-remote`'s eight stores, the Python wheels, the npm packages, `dynamic-config-py-web`, the axum and Actix adapters, `dynamic-config-cli` | supported, released and tested on every change to the core; their dependency surface moves with their clients (AWS SDK, etcd, PyO3, napi), so most of the churn lives here |
| **3 — specialised** | `dynamic-config-embedded`, `dynamic-config-server` | narrower audiences, same gates, fewer callers to break; a change here is not a change to the engine |

## Stability

Every crate and package is **Beta**, with two named exceptions: the
**Robyn** and **django-bolt** adapters in `dynamic-config-py-web` are
**Experimental**, because those frameworks are young and their process
models are the part an adapter depends on most. Pre-1.0 a breaking change
bumps the minor version and a patch never breaks, so pinning the minor and
taking patches automatically is the intended way to depend on this.

**The engine's surface is finished for 0.x**: no new sources, no new
stores, no new methods on the settled types. That is a decision, not a
pause — nothing new lands there until the current surface has been used
enough to know what is wrong with it.

**The bindings are younger than the engine**, and where using one turns
up a missing piece, it is added and announced as an addition rather than
smuggled in as a hotfix. Both bindings grew their concurrency surface once
— `dynamic-config-python` 0.2 and `dynamic-config-node` 0.0.3 — and each
[stability page](https://dynamic-config-rs.github.io/python/stability.html)
says what it added and why.

What happens before 1.0 in either case is evidence — conformance across
the three languages, soak and chaos runs, fuzzing, and whatever real use
turns up.

## Contributing

Each repository carries its own `CONTRIBUTING.md`, its own gate
(`just check`) and its own book. Security reports go through the private
advisory form of the repository that owns the code — the address is in
each `SECURITY.md`.

<sub>MIT licensed. Released from `github.com/ctolon/dynamic-config` until
0.6.1, and from this organisation since.</sub>
