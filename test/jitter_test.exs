defmodule JitterTest do
  use ExUnit.Case
  doctest Jitter

  test "greets the world" do
    assert Jitter.hello() == :world
  end
end
