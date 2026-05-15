# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-05-15

### Added
- `Jitter.no_jitter/2`, `full/2`, `equal/2`, `decorrelated/2` — pure functions for the four jitter strategies from Marc Brooker's *Exponential Backoff and Jitter*.
- `Jitter.full_stream/1`, `Jitter.equal_stream/1`, `Jitter.decorrelated_stream/1` — infinite lazy `Stream` generators, with `decorrelated_stream/1` carrying `prev_delay` as internal state via `Stream.unfold/2`.
- `Jitter.apply_full/2` and `Jitter.apply_equal/2` — `Stream` transformers that layer jitter onto any existing delay enumerable (drop-in compatible with `Retry.DelayStreams`).
- Configurable RNG via the `:rng` option on every function and stream for deterministic testing.
