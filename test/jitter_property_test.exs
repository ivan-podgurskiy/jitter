defmodule JitterPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "no_jitter/2 is non-decreasing until cap" do
    check all(
            base <- integer(1..1000),
            cap <- integer(base..30_000),
            max_runs: 1000
          ) do
      results = Enum.map(0..20, &Jitter.no_jitter(&1, base: base, cap: cap))

      pairs = Enum.zip(results, tl(results))

      assert Enum.all?(pairs, fn {x, y} -> y >= x end)
    end
  end

  property("full/2 always returns value in [0, max_delay]") do
    check all(
            attempt <- integer(0..30),
            base <- integer(1..1000),
            cap <- integer(base..30_000),
            max_runs: 1000
          ) do
      result = Jitter.full(attempt, base: base, cap: cap)
      expected_max_delay = capped_exponential_delay(attempt, base, cap)

      assert result >= 0
      assert result <= expected_max_delay
    end
  end

  property("equal/2 always returns value in [half_delay, max_delay]") do
    check all(
            attempt <- integer(0..30),
            base <- integer(1..1000),
            cap <- integer(base..30_000),
            max_runs: 1000
          ) do
      result = Jitter.equal(attempt, base: base, cap: cap)
      expected_max_delay = capped_exponential_delay(attempt, base, cap)
      half_delay = div(expected_max_delay, 2)

      assert result >= half_delay
      assert result <= expected_max_delay
    end
  end

  property("decorrelated/2 always returns value in [base, max_delay]") do
    check all(
            base <- integer(1..1000),
            cap <- integer(base..30_000),
            prev_delay <- integer(base..cap),
            max_runs: 1000
          ) do
      result = Jitter.decorrelated(prev_delay, base: base, cap: cap)
      expected_max_delay = min(cap, max(base, prev_delay * 3))

      assert result >= base
      assert result <= expected_max_delay
    end
  end

  defp capped_exponential_delay(attempt, base, cap) do
    min(cap, base * Integer.pow(2, attempt))
  end
end
