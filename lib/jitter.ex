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

  @doc """
  Returns an infinite lazy stream of full jitter delays.

  Each element is calculated from the next retry attempt:

      attempt 0, attempt 1, attempt 2, ...

  Use `Enum.take/2` or `Stream.take/2` to consume a finite number of values.

  ## Examples

      iex> Jitter.full_stream(base: 100, cap: 1000, rng: fn _min, max -> max end) |> Enum.take(5)
      [100, 200, 400, 800, 1000]
  """
  @spec full_stream(keyword()) :: Enumerable.t()
  def full_stream(opts \\ []) do
    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(&full(&1, opts))
  end

  @doc """
  Returns an infinite lazy stream of equal jitter delays.

  Each element is calculated from the next retry attempt. The delay is always
  between half of the capped exponential delay and the full capped exponential delay.

  Use `Enum.take/2` or `Stream.take/2` to consume a finite number of values.

  ## Examples

      iex> Jitter.equal_stream(base: 100, cap: 1000, rng: fn _min, max -> max end) |> Enum.take(5)
      [100, 200, 400, 800, 1000]

      iex> Jitter.equal_stream(base: 100, cap: 1000, rng: fn min, _max -> min end) |> Enum.take(5)
      [50, 100, 200, 400, 500]
  """
  @spec equal_stream(keyword()) :: Enumerable.t()
  def equal_stream(opts \\ []) do
    Stream.iterate(0, &(&1 + 1))
    |> Stream.map(&equal(&1, opts))
  end

  @doc """
  Returns an infinite lazy stream of decorrelated jitter delays.

  Unlike `full_stream/1` and `equal_stream/1`, this stream keeps the previous delay
  as internal state. Each generated delay becomes the previous delay for the next step.

  Use `Enum.take/2` or `Stream.take/2` to consume a finite number of values.

  ## Examples

      iex> Jitter.decorrelated_stream(base: 100, cap: 1000, rng: fn _min, max -> max end) |> Enum.take(5)
      [300, 900, 1000, 1000, 1000]
  """
  @spec decorrelated_stream(keyword()) :: Enumerable.t()
  def decorrelated_stream(opts \\ []) do
    base = Keyword.get(opts, :base, @default_base)

    Stream.unfold(base, fn prev_delay ->
      next_delay = decorrelated(prev_delay, opts)
      {next_delay, next_delay}
    end)
  end

  @doc """
  Applies Full Jitter to an existing delay stream.

  Each delay in the input enumerable is capped at `:cap` and then randomized
  uniformly in `[0, capped]`. Compatible with `Retry.DelayStreams.exponential_backoff/0`:

      import Retry.DelayStreams
      exponential_backoff() |> Jitter.apply_full(cap: 30_000) |> Stream.take(5)

  ## Examples

      iex> [100, 200, 400, 800, 2000]
      ...> |> Jitter.apply_full(cap: 1000, rng: fn _min, max -> max end)
      ...> |> Enum.to_list()
      [100, 200, 400, 800, 1000]
  """
  @spec apply_full(Enumerable.t(), keyword()) :: Enumerable.t()
  def apply_full(delays, opts) do
    cap = Keyword.fetch!(opts, :cap)
    rng = Keyword.get(opts, :rng, &default_rng/2)

    Stream.map(delays, fn delay ->
      capped = min(cap, delay)
      trunc(rng.(0, capped))
    end)
  end

  @doc """
  Applies Equal Jitter to an existing delay stream.

  Each delay in the input enumerable is capped at `:cap` and then split in half:
  the result is the half plus a uniform random value in `[0, half]`. Compatible
  with `Retry.DelayStreams.exponential_backoff/0`:

      import Retry.DelayStreams
      exponential_backoff() |> Jitter.apply_equal(cap: 30_000) |> Stream.take(5)

  ## Examples

      iex> [100, 200, 400, 800, 2000]
      ...> |> Jitter.apply_equal(cap: 1000, rng: fn _min, max -> max end)
      ...> |> Enum.to_list()
      [100, 200, 400, 800, 1000]

      iex> [100, 200, 400, 800, 2000]
      ...> |> Jitter.apply_equal(cap: 1000, rng: fn min, _max -> min end)
      ...> |> Enum.to_list()
      [50, 100, 200, 400, 500]
  """
  @spec apply_equal(Enumerable.t(), keyword()) :: Enumerable.t()
  def apply_equal(delays, opts) do
    cap = Keyword.fetch!(opts, :cap)
    rng = Keyword.get(opts, :rng, &default_rng/2)

    Stream.map(delays, fn delay ->
      capped = min(cap, delay)
      half = capped / 2
      trunc(half + rng.(0, half))
    end)
  end
end
