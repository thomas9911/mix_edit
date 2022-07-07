defmodule OneAppTest do
  use ExUnit.Case
  doctest OneApp

  test "greets the world" do
    assert OneApp.hello() == :world
  end
end
