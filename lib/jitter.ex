defmodule Jitter do
  @moduledoc """
  Backoff jitter strategies based on Marc Brooker's
  "Exponential Backoff and Jitter" (AWS Architecture Blog, 2015).
  """

  @default_base 100
  @default_cap 30_000

  @doc """
  Returns capped exponential delay without jitter.

  This is the baseline — no randomness, just exponential growth.
  Use this only as a reference; in production prefer `full/2` or `decorrelated/2`.

  ## Examples

      iex> Jitter.no_jitter(0, base: 100, cap: 30_000)
      100

      iex> Jitter.no_jitter(3, base: 100, cap: 30_000)
      800

      iex> Jitter.no_jitter(20, base: 100, cap: 1000)
      1000
  """
  @spec no_jitter(non_neg_integer(), keyword()) :: pos_integer()
  def no_jitter(attempt, opts) when is_integer(attempt) and attempt >= 0 do
    base = Keyword.get(opts, :base, @default_base)
    cap = Keyword.get(opts, :cap, @default_cap)

    capped_delay(cap, base, attempt)
  end

  @doc """
  Returns capped exponential delay with full jitter.

  ## Examples

      iex> Jitter.full(0, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      100

      iex> Jitter.full(3, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      800

      iex> Jitter.full(20, base: 100, cap: 1000, rng: fn _min, max -> max end)
      1000
  """
  @spec full(non_neg_integer(), keyword()) :: pos_integer()
  def full(attempt, opts) when is_integer(attempt) and attempt >= 0 do
    base = Keyword.get(opts, :base, @default_base)
    cap = Keyword.get(opts, :cap, @default_cap)
    rng = Keyword.get(opts, :rng, &default_rng/2)

    max_delay = capped_delay(cap, base, attempt)

    trunc(rng.(0, max_delay))
  end

  @doc """
  Returns capped exponential delay with equal jitter.

  ## Examples

      iex> Jitter.equal(0, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      100

      iex> Jitter.equal(3, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      800

      iex> Jitter.equal(20, base: 100, cap: 1000, rng: fn _min, max -> max end)
      1000
  """
  @spec equal(non_neg_integer(), keyword()) :: pos_integer()
  def equal(attempt, opts) when is_integer(attempt) and attempt >= 0 do
    base = Keyword.get(opts, :base, @default_base)
    cap = Keyword.get(opts, :cap, @default_cap)
    rng = Keyword.get(opts, :rng, &default_rng/2)

    half = capped_delay(cap, base, attempt) / 2

    trunc(half + rng.(0, half))
  end

  @doc """
  Returns capped exponential delay with decorrelated jitter.

  ## Examples

      iex> Jitter.decorrelated(100, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      300

      iex> Jitter.decorrelated(200, base: 100, cap: 30_000, rng: fn min, _max -> min end)
      100

      iex> Jitter.decorrelated(20_000, base: 100, cap: 30_000, rng: fn _min, max -> max end)
      30000
  """
  @spec decorrelated(pos_integer(), keyword()) :: pos_integer()
  def decorrelated(prev_delay, opts) when is_integer(prev_delay) and prev_delay > 0 do
    base = Keyword.get(opts, :base, @default_base)
    cap = Keyword.get(opts, :cap, @default_cap)
    rng = Keyword.get(opts, :rng, &default_rng/2)

    trunc(min(cap, rng.(base, max(base, prev_delay * 3))))
  end

  defp default_rng(min, max), do: min + :rand.uniform() * (max - min)

  defp capped_delay(cap, base, attempt), do: min(cap, base * Integer.pow(2, attempt))
end
