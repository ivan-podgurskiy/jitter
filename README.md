# Jitter

Backoff jitter strategies (No, Full, Equal, Decorrelated) from Marc Brooker's
[*Exponential Backoff and Jitter*](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/),
exposed as pure functions, ready-made `Stream`s, and `Stream` transformers that
drop into existing retry pipelines.

## Why

Most retry libraries ship a single "add randomness" knob and call it a day.
Brooker's 2015 post showed that the *shape* of the randomness matters: under
contention, **Full** and **Decorrelated** jitter dramatically reduce total client
work compared to additive or multiplicative jitter. Ten years later, that
finding is still missing from most ecosystems.

| Ecosystem | Library                         | No  | Full | Equal | Decorrelated | Notes                                                          |
| --------- | ------------------------------- | :-: | :--: | :---: | :----------: | -------------------------------------------------------------- |
| Elixir    | `retry`                         |  ✓  |  —   |   —   |      —       | `randomize/2` is multiplicative ±jitter, not Brooker's Full    |
| Elixir    | **`jitter` (this package)**     |  ✓  |  ✓   |   ✓   |    **✓**     | All four named strategies, as pure functions + streams         |
| Python    | `tenacity`                      |  ✓  |  ✓¹  |   —   |      —       | `wait_random_exponential` ≈ Full; no Decorrelated              |
| Python    | `backoff`                       |  ✓  |  ✓²  |   —   |      —       | `expo(..., jitter=full_jitter)`                                |
| JavaScript| `p-retry` / `async-retry`       |  ✓  |  —   |   —   |      —       | `randomize` flag adds a multiplicative factor only             |
| Go        | `cenkalti/backoff`              |  ✓  |  —   |   —   |      —       | `RandomizationFactor` is multiplicative ±jitter                |
| Java      | `Resilience4j`                  |  ✓  |  —   |  ✓³   |      —       | `ofExponentialRandomBackoff` ≈ Equal; no Decorrelated          |
| Java/AWS  | `aws-sdk-java-v2`               |  ✓  |  ✓   |   ✓   |      —       | `FullJitterBackoffStrategy`, `EqualJitterBackoffStrategy`      |
| .NET      | `Polly`                         |  ✓  |  ✓   |   —   |    **✓**     | `Backoff.DecorrelatedJitterBackoffV2` — the rare exception     |
| Ruby      | `retriable`                     |  ✓  |  —   |   —   |      —       | `rand_factor` is multiplicative ±jitter                        |

<sub>¹ `tenacity.wait_random_exponential` computes `random(0, min(cap, base·2^n))`, which matches Full.</sub>  
<sub>² `backoff.expo(jitter=backoff.full_jitter)` matches Full.</sub>  
<sub>³ Resilience4j's randomized exponential picks uniformly inside ±factor of the deterministic delay, which is closer to Equal than to Full.</sub>

If your stack is on the right of that table, `jitter` is the smallest possible
dependency that gives you the strategy Brooker actually recommends as the
default (Full) and the one he recommends under heavy contention (Decorrelated).

## Installation

Add `:jitter` to your dependencies in `mix.exs`:

```elixir
def deps do
  [{:jitter, "~> 0.1.0"}]
end
```

Then:

```bash
mix deps.get
```

Documentation is on [HexDocs](https://hexdocs.pm/jitter).

## Quick start

### 1. Standalone — compute a single delay

Use the pure functions when you control the retry loop yourself:

```elixir
delay = Jitter.full(attempt, base: 100, cap: 30_000)
Process.sleep(delay)
```

`no_jitter/2`, `full/2`, `equal/2` all take an attempt number (starts at `0`).
`decorrelated/2` is different — it takes the **previous delay**, because each
value depends on the last one:

```elixir
prev = 100
next = Jitter.decorrelated(prev, base: 100, cap: 30_000)
```

### 2. As a Stream — drive your own retry loop lazily

Every strategy has a matching infinite `Stream`:

```elixir
Jitter.full_stream(base: 100, cap: 30_000)
|> Stream.take(5)
|> Enum.each(&Process.sleep/1)
```

Decorrelated keeps `prev_delay` as internal state via `Stream.unfold/2`, so you
get a properly correlated sequence without writing the loop yourself:

```elixir
Jitter.decorrelated_stream(base: 100, cap: 30_000)
|> Stream.take(10)
|> Enum.to_list()
```

### 3. Drop-in with the [`retry`](https://hex.pm/packages/retry) library

`Retry.retry/2` accepts any `Enumerable` of millisecond delays via `:with`, so a
`jitter` stream slots in where `Retry.DelayStreams.exponential_backoff/0` would
normally go:

```elixir
use Retry

retry with: Jitter.full_stream(base: 100, cap: 5_000) |> Stream.take(10) do
  HTTPClient.get("https://api.example.com/flaky")
after
  {:ok, response} -> response
else
  error -> error
end
```

Already using `Retry.DelayStreams` and just want to layer jitter on top? Use
`apply_full/2` or `apply_equal/2` as a `Stream` transformer — each delay is
capped at `:cap` and randomized in place:

```elixir
import Retry.DelayStreams

exponential_backoff()
|> Jitter.apply_full(cap: 30_000)
|> Stream.take(10)
```

Swap `full_stream` (or `apply_full`) for `decorrelated_stream` if your
downstream is contended — that's the case Brooker's post is really about.
Decorrelated has no `apply_*` transformer because each delay depends on the
previous one; use `decorrelated_stream/1` directly.

### Deterministic testing

Every strategy accepts an optional `:rng` so tests don't have to be flaky:

```elixir
deterministic = fn _min, max -> max end
Jitter.full(3, base: 100, cap: 30_000, rng: deterministic)
# => 800
```

## Strategies

All four come from §"Adding Jitter" of
[Brooker, 2015](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/).
Notation: `cap_delay = min(cap, base · 2^attempt)`.

- **`no_jitter/2`** — `cap_delay`. The deterministic exponential baseline.
  Included as a reference; **don't use this in production** — it's the worst
  case in Brooker's contention simulation.

- **`full/2`** — `U(0, cap_delay)`. Picks a uniformly random delay in
  `[0, cap_delay)`. Brooker's recommended default. Slightly higher latency
  variance than Equal, but lower total work under contention.

- **`equal/2`** — `cap_delay/2 + U(0, cap_delay/2)`. Half deterministic
  backoff, half jitter. Tighter latency bounds than Full but does more
  redundant work under contention.

- **`decorrelated/2`** — `min(cap, U(base, prev_delay · 3))`. Each delay is
  derived from the previous one rather than the attempt number, so retries from
  a single client don't bunch up. Use this when contention is the failure mode
  you're protecting against.

## License

MIT — see [LICENSE](https://github.com/ivan-podgurskiy/jitter/blob/main/LICENSE).
