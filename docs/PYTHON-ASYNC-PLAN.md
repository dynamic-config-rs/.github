# Python binding: async architecture and multi-config lifecycle

An implementation plan, from an outside review of the concurrency design.
Rayon is out of scope by decision; Tokio stays out of the base wheel for
the reasons in §7.

Everything below was checked against the code rather than taken from the
review:

| Claim | Verified |
|---|---|
| `changed_async` / `changes` poll in 250 ms slices on the loop's default executor | `_config.py:806-870` — yes |
| the Rust binding's `wait_for_change` is a `Condvar` wait with the GIL released | `src/config/mod.rs:715` — yes |
| the engine already has a real `Future` with waker registration | `asynchronous.rs:158` `Changes<T>`, `poll` at 233 — yes |
| `on_reload` runs on the thread that performed the reload | `_config.py:722` says so — yes |
| the engine already has all-or-nothing multi-config reload | `group.rs:67` `ReloadGroup`, prepare-all → commit-all — **yes, and it is not exposed to Python** |
| `set_executor` exists, with no naming or ownership policy | `_executor.py` — yes |

Two consequences of the last two rows change the plan's shape: the atomic
group reload is a *binding* job rather than an engine one, and the event
loop bridge is the only place where new Rust is unavoidable.

---

## What this costs, before anything else

Every README, the org profile and `book/src/stability-tiers.md` currently
say: **between 0.6.1 and 1.0, only security fixes and hotfixes land.**
This plan is neither. Doing it means one of:

- **Amend the promise**, honestly: "the surface is settled *except* for the
  async and multi-config work tracked in this plan, which lands in 0.7 /
  0.2 and is additive." Every existing call keeps working — nothing below
  removes or changes a signature.
- **Or hold the plan** until 1.0 and ship it as 1.1.

Recommendation: amend, in one sentence, in the four places that carry the
sentence — and say *why*, because the reason is good: the binding is
currently making an async user pay for a polling loop the engine does not
need.

Version shape: engine **0.7.0** (§2 needs one small Rust change), Python
wheels **0.2.0**. Node is untouched by this plan; §9 says what it would
inherit later.

---

## Phase 1 — ergonomics, no new concurrency (0.2.0)

Nothing here changes a thread's behaviour. All of it removes boilerplate
that the library currently pushes onto the application.

### 1.1 `ConfigGroup`

```python
group = ConfigGroup(db, redis, kafka, auth, features)

group.init()                      # every member, in order
with group.watch():               # every member's watcher, stopped together
    run()

group.reload()                    # each member, independently
group.status()                    # {key: Status}, one call
group.stop()
```

Async twins: `init_async`, `watch_async` (an async context manager),
`reload_async`, and `concurrency=` bounding both (§4.2).

The group owns *lifecycle*, not storage: `group.db` is not a thing;
`db.current()` stays the read path. That keeps the group out of the hot
path entirely.

**Files:** new `python/dynamic_config/_group.py`, exported from
`__init__.py`. No Rust.

### 1.2 Context managers for what already has `stop()`

```python
with config.watch() as watch:      # Watch gains __enter__/__exit__
    run()

async with config.watching():      # sugar for watch + stop, on the loop
    await serve()

with config.running(watch=True):   # init + watch on entry, stop on exit
    ...
async with config.running_async(watch=True):
    ...
```

`Watch.stop()` is already idempotent (`Mutex<Option<WatchHandle>>` in the
binding), so `__exit__` is a call to it and nothing else.

**Files:** `_config.py`, `_lifetime.py`. No Rust.

### 1.3 Thread names

`dynamic-config-watch-db`, `dynamic-config-notify-db`,
`dynamic-config-exec-0`. Derived from the configuration key; no API. A
production thread dump stops saying `Thread-17`.

**Files:** the binding's watch spawn (`src/config/`), `_executor.py`.

### 1.4 Executor ergonomics, and ownership

```python
dynamic_config.configure_executor(max_workers=4)   # library-owned, shut down at exit
dynamic_config.set_executor(pool)                  # caller-owned, never shut down

with dynamic_config.executor(max_workers=2):       # scoped, for tests
    ...
```

Ownership is tracked internally and never guessed: a pool the caller
passed is never shut down by the library, and a pool the library made is
shut down through the existing `atexit` path.

**Files:** `_executor.py`.

---

## Phase 2 — the event-loop bridge (0.7.0 engine + 0.2.0 wheels)

The one architectural change, and the reason for the engine bump.

### Today

```text
asyncio task → default ThreadPoolExecutor → Condvar wait (250 ms)
            → return → re-submit → …            per waiter, forever
```

Fifty configurations with two consumers each is a hundred repeating
executor submissions that exist only so that cancellation is noticed
within a quarter second.

### After

```text
Rust watcher → install → generation++ → notify
                                          │
              one notifier thread per configuration (lazy, shared)
                                          │
                        loop.call_soon_threadsafe(future.set_result)
                                          │
                                    awaiting tasks
```

One parked thread per *configuration that has async consumers*, not per
consumer, and no polling at all.

### The Rust change that makes it terminable

The notifier must block until the next install **or until the
configuration goes away** — today the only wake is an install, so a
process with a live notifier and no further reloads would keep the thread
until exit. `Wake` gains a flag:

```rust
struct Wake {
    generation: Mutex<u64>,
    changed: Condvar,
    closed: AtomicBool,     // set by `release()`; `wait_for_change` returns
}
```

`wait_for_change` returns `None` when `closed` is set, and `release()`
sets it and calls `notify_all`. That is ~15 lines in
`dynamic-config-python/src/config/mod.rs`, and it is the whole engine-side
cost of this phase.

### The Python side

```python
class _Notifier:
    """One thread per configuration, started with the first waiter."""
    def _run(self):
        while not self._closed:
            result = core.wait_for_change(self._seen, None)   # no timeout
            if result is None:
                break
            self._seen, model = result
            for loop, future in self._waiters.drain():
                loop.call_soon_threadsafe(_resolve, future, model)
```

`changed_async` becomes: register a future, await it. `changes()` becomes:
register, await, re-register — with **latest-wins preserved**, because the
notifier resolves with what is installed when it wakes rather than with a
queue.

Cancellation is now immediate: a cancelled task drops its future and the
notifier stops when its last waiter goes.

**Measurable claim to put in the book:** cancelling `changed_async` is
observed in microseconds instead of ≤250 ms, and a process with N
configurations and M consumers parks N threads instead of submitting
N × M × 4 executor tasks per second.

**Files:** `src/config/mod.rs` (the `closed` flag), new
`python/dynamic_config/_notify.py`, `_config.py` (`changed_async`,
`changes`), tests in `tests/test_async.py`.

---

## Phase 3 — async callbacks and dispatch policy (0.2.0)

### 3.1 Async hooks

```python
@config.on_reload_async
async def handle(previous, current):
    await pool.resize(current.pool.max_size)

@config.on_change_async("redis.url")
async def reconnect(previous, current):
    await redis.reconnect(current)
```

Semantics, and they are the point: **the watcher never awaits the
callback.** The hook is scheduled with `loop.call_soon_threadsafe` →
`create_task`, so reload latency and callback latency are different
numbers. A hook registered from a thread with no running loop is an error
at registration, not a hang at reload.

### 3.2 Dispatch, as a typed enum

```python
from dynamic_config import Dispatch

@config.on_reload(dispatch=Dispatch.EXECUTOR)
def rebuild(previous, current):
    expensive()

@config.on_reload(dispatch=Dispatch.ASYNCIO)
async def reconnect(previous, current):
    await client.reconnect()
```

```python
class Dispatch(str, Enum):
    """Where a hook runs. `str` so that `dispatch="inline"` keeps working
    and a config file can name one; `Enum` so that a typo is a
    `ValueError` at registration rather than silence at reload."""
    INLINE = "inline"       # today's behaviour, and the default
    EXECUTOR = "executor"   # the configuration executor, off the watcher
    ASYNCIO = "asyncio"     # a task on the loop that registered the hook
```

`str, Enum` rather than 3.11's `StrEnum`: the floor is CPython 3.9.

### 3.3 Backpressure, also typed

```python
class Backpressure(str, Enum):
    EVERY = "every"                      # one call per install (default for INLINE)
    LATEST = "latest"                    # coalesce; default for ASYNCIO/EXECUTOR
    SERIAL = "serial"                    # queue, one at a time, never drop
    CANCEL_PREVIOUS = "cancel_previous"  # a new install cancels the running task
```

`LATEST` is what `changes()` already does, and it is the right default for
a *configuration* callback: rebuilding a pool for a size nobody is asking
for any more is work done for nothing. `SERIAL` exists for the audit-log
shape, where dropping is wrong.

**Files:** `_config.py` (registration + dispatch), new
`python/dynamic_config/_dispatch.py` for the two enums, `_core.pyi`,
tests.

---

## Phase 4 — the group, doing real work (0.7.0 + 0.2.0)

### 4.1 Atomic reload across configurations

The engine already does this for Rust callers: `ReloadGroup` prepares
every member and commits only if all prepared. The Python binding has no
value-level equivalent, so this is a binding job:

```python
snapshot = group.reload_atomic()     # all validate, or nothing installs
snapshot.db, snapshot.redis          # one logical generation
```

Requires a `prepare()` / `commit(prepared)` pair on the binding's core
object. `load()` (validate, install nothing) is half of it already; what
is missing is a commit that moves the engine's own metadata — `replace()`
deliberately does not, which is documented and would leave
`status().generation` stale if it were used here.

**Files:** `src/config/mod.rs` (`prepare`/`commit`), `_group.py`,
`_core.pyi`.

### 4.2 Bounded concurrent startup

```python
group = ConfigGroup(db, redis, kafka, concurrency=4)
group.init()                # threads, bounded
await group.init_async()    # gather, bounded by a semaphore
```

Independent configurations, independent files: this is the one place in
the library where parallelism is obviously worth it, and it is bounded so
that fifty configurations do not become fifty threads.

### 4.3 One watcher for a group

Today: one OS watcher thread per configuration. For ten, fine; for a
thousand, not.

```text
group.watch()
   └── one notify::Watcher
         ├── /etc/app/db.toml     → db
         ├── /etc/app/redis.toml  → redis
         └── /etc/app/kafka.toml  → kafka
```

Deferred to its own phase deliberately: it needs a path→configuration
index, debounce shared across members, and a failure story per member.
Worth doing after §2 and §4.1, and worth benchmarking first — the review
rates it above Tokio, and that matches what the numbers are likely to say.

---

## Phase 5 — remote sources that are actually async (0.2.0)

```python
class Store(AsyncRemoteSource):
    async def fetch(self) -> tuple[str, Format]:
        async with httpx.AsyncClient() as client:
            response = await client.get(URL)
            return response.text, Format.JSON

config.remote(Store())            # detected by protocol, not by a flag
await config.refresh_remote_async()
```

The bridge is the one the Node package already uses: the fetch runs on the
loop, its answer is kept, and the engine's remote layer — which is filled
from a worker thread and must be handed something synchronous — reads the
kept answer.

Calling `refresh_remote()` (sync) on a configuration holding an async
source raises, naming the method to call instead. Sync sources keep
working unchanged in both.

**Files:** `_remote.py`, `remote.py`, `_config.py`, `_core.pyi`.

---

## Phase 6 — observability: an event stream (0.2.0)

```python
async for event in config.events():
    match event:
        case Reloaded(generation=g, changed_paths=paths, source=src): ...
        case ReloadFailed(error=error, consecutive=n): ...
        case RemoteRefreshed(): ...
```

Plus the cheap half, available without a stream:

```python
watch.failure_count
watch.last_error       # the error, never a value from the document
watch.last_success     # a timestamp
```

`changes()` stays exactly as it is — the simple model stream — and
`events()` is the diagnostic one. **No event carries a value**, only paths,
kinds and counts: the secret rule applies here like everywhere else.

**Files:** `_config.py`, new `python/dynamic_config/_events.py`,
`_core.pyi`.

---

## Explicitly not doing

- **Tokio in the base wheel.** Today `await config.reload_async()` is
  `asyncio → ThreadPoolExecutor → sync Rust`. Adding Tokio underneath
  leaves that path identical and adds a second runtime to every install.
  It becomes interesting only if the *remote wheel* grows native async
  I/O against etcd/Vault/NATS, where the clients are Tokio-native
  already — a separate decision, in a separate package, after §5.
- **Rayon**, anywhere. Out of scope by decision, and the review's own
  analysis agrees for the single-config path.
- **AnyIO in the base package.** The engine is runtime-agnostic and the
  binding is asyncio-specific; closing that gap costs a dependency for
  every user to serve Trio users, who can already drive the sync API from
  a worker thread. Revisit only if asked for by someone using it.
- **A separate `config.asyncio.*` facade.** `_async` suffixes are what a
  Python reader expects; a second namespace doubles the surface for
  nothing.
- **`asyncio.to_thread`.** It is 3.9+, so it *is* available — but it
  hard-codes the default executor, and `set_executor` exists precisely so
  that configuration work does not queue behind an unrelated batch job.
  `run_in_executor` stays.

---

## Documentation this changes

Not an afterthought: every phase lands with its prose in the same pull
request, which is what the drift gates in this repository exist to
enforce.

| Where | What |
|---|---|
| `book-python/src/async.md` | rewritten around the bridge: no polling, cancellation is immediate, what a notifier thread is and when one exists |
| `book-python/src/callbacks.md` | the dispatch and backpressure tables, and the rule that a watcher never awaits a hook |
| `book-python/src/reference.md` | `ConfigGroup`, `Dispatch`, `Backpressure`, `AsyncRemoteSource`, `events()`, the context managers |
| `book-python/src/patterns.md` | one group per service; FastAPI `lifespan` with `running_async` |
| `book-python/src/limitations.md` | what is still sync (the file read itself), why no Tokio, why no AnyIO |
| `book/src/stability-tiers.md` + the four READMEs + org profile | the amended sentence from the top of this plan |
| `dynamic-config-python/CHANGELOG.md` | one entry per phase, under `Unreleased` |

## Examples to add

`dynamic-config-python/examples/` has 23 today, each runnable and run in
CI. Four more, in the same shape:

```text
24_config_group.py          five configurations, one lifecycle, bounded startup
25_async_callbacks.py       on_change_async + Dispatch.ASYNCIO + Backpressure.LATEST
26_async_remote_source.py   AsyncRemoteSource against a local HTTP server
27_atomic_group_reload.py   reload_atomic with one member that refuses
```

Each must run without a network and without a service — the pattern the
existing twenty-three follow.

## Tests

- **§2**: cancellation observed in < 10 ms; N configurations with M
  consumers park N threads; a `release()`d configuration ends its notifier.
- **§3**: a slow async hook does not delay the next reload; `LATEST`
  coalesces three installs into one call; `CANCEL_PREVIOUS` cancels;
  registration from a loopless thread raises.
- **§4.1**: one member refusing means no member installs, and every
  member's `status().generation` is unchanged.
- **§4.2**: `concurrency=2` never runs three at once (a counting fixture).
- **§5**: a sync call against an async source raises and names the fix.
- **§6**: no event carries a document value — the same assertion
  `tests/test_security.py` already makes for diagnostics.

Plus the free-threaded suite for §2 and §3: the notifier and the dispatch
paths are exactly where a GIL assumption would hide.

## Order, and why

```text
1 ergonomics ──► 2 bridge ──► 3 callbacks ──► 4 group work ──► 5 async remote ──► 6 events
   no risk       the one       needs 2's       needs 2 and         needs 3's        needs 3
                 engine        scheduling      a Rust commit       dispatch
                 change
```

§1 is shippable on its own and makes the rest easier to write. §2 is the
one that has to be right; everything after it either schedules onto the
bridge or reads from it.
