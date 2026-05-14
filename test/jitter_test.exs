defmodule JitterTest do
  use ExUnit.Case
  doctest Jitter

  describe "no_jitter/2" do
    test "return base for attempt 0" do
      assert Jitter.no_jitter(0, base: 100, cap: 30_000) == 100
    end

    test "uses exponential backoff for subsequent attempts" do
      assert Jitter.no_jitter(1, base: 100, cap: 30_000) == 200
      assert Jitter.no_jitter(2, base: 100, cap: 30_000) == 400
      assert Jitter.no_jitter(3, base: 100, cap: 30_000) == 800
    end

    test "respects the cap" do
      assert Jitter.no_jitter(10, base: 100, cap: 30_000) == 30_000
    end
  end

  describe "full/2" do
    test "results between 0 and cap" do
      for attempt <- 0..5 do
        result = Jitter.full(attempt, base: 100, cap: 30_000)
        assert result >= 0
        assert result <= min(30_000, 100 * Integer.pow(2, attempt))
      end
    end

    test "uses RNG with calculated max delay" do
      rng = fn _min_delay, max_delay ->
        div(max_delay, 2)
      end

      assert Jitter.full(0, base: 100, cap: 30_000, rng: rng) == 50
      assert Jitter.full(1, base: 100, cap: 30_000, rng: rng) == 100
      assert Jitter.full(2, base: 100, cap: 30_000, rng: rng) == 200
      assert Jitter.full(3, base: 100, cap: 30_000, rng: rng) == 400
    end

    test "respects the cap" do
      for _ <- 1..100 do
        assert Jitter.full(100, base: 100, cap: 30_000) in 0..30_000
      end
    end
  end

  describe "equal/2" do
    # tmp = min(cap, base * 2 ** attempt)
    # delay = tmp/2 + rand(0, tmp/2)
    test "results between 0 and cap" do
      for attempt <- 0..5 do
        result = Jitter.equal(attempt, base: 100, cap: 30_000)
        assert result >= 0
        assert result <= min(30_000, 100 * Integer.pow(2, attempt))
      end
    end

    test "equal jitter returns value between half delay and full delay" do
      rng = fn _min, max -> max end

      assert Jitter.equal(2, base: 100, cap: 30_000, rng: rng) == 400
    end

    test "equal/2 handle odd base upper edge" do
      rng = fn _min, max -> max end

      result = Jitter.equal(0, base: 99, cap: 30_000, rng: rng)
      assert result == 99
    end

    test "handles odd base correctly" do
      # base=99, attempt=0: delay=99, half=49.5
      # result must be in [49.5, 99] -> trunc -> [49, 99]
      for _ <- 1..100 do
        result = Jitter.equal(0, base: 99, cap: 30_000)
        assert result >= 49
        assert result <= 99
      end
    end

    test "respects the cap" do
      assert Jitter.equal(10, base: 100, cap: 30_000) in 0..30_000
    end
  end

  describe "decorrelated/2" do
    test "returns value between base and previous delay times three" do
      rng = fn min, max ->
        assert min == 100
        assert max == 300
        200
      end

      assert Jitter.decorrelated(100, base: 100, cap: 30_000, rng: rng) == 200
    end

    test "decorrelated/2 with prev_delay < base produces invalid result (bug demo)" do
      # rng returns max boundary: min + 1.0 * (max - min) = max
      rng = fn _min, max -> max end

      # prev_delay=10, base=100: rng(100, 30) -> returns 30 (max)
      # 30 < 100 (base) => contract violation
      result = Jitter.decorrelated(10, base: 100, cap: 30_000, rng: rng)

      assert result >= 100,
             "Expected result >= base (100), got #{result}"
    end

    test "respect the cap" do
      assert Jitter.decorrelated(1234, base: 100, cap: 30_000) in 0..30_000
    end
  end
end
