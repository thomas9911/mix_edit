defmodule MixAddTest do
  use ExUnit.Case
  doctest MixAdd

  test "greets the world" do
    assert MixAdd.hello() == :world
  end
end
