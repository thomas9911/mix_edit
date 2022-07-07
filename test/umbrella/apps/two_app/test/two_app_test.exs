defmodule TwoAppTest do
  use ExUnit.Case
  doctest TwoApp

  test "greets the world" do
    assert TwoApp.hello() == :world
  end
end
