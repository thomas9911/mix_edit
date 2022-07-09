defmodule MixEditTest do
  use ExUnit.Case
  doctest MixEdit

  test "adds new dependency" do
    expected = [{:ex_doc, ">= 0.0.0"}]
    deps = [] |> inspect() |> MixEdit.quote_string!() |> unwrap_deps()

    assert {expected, []} ==
             deps
             |> MixEdit.add_deps([{:ex_doc, ">= 0.0.0"}])
             |> Code.eval_quoted()
  end

  test "appends new dependency" do
    expected = [{:ex_doc, ">= 0.0.0"}, {:plug, "~> 1.0"}]
    deps = [{:ex_doc, ">= 0.0.0"}] |> inspect() |> MixEdit.quote_string!() |> unwrap_deps()

    assert {expected, []} ==
             deps
             |> MixEdit.add_deps([{:plug, "~> 1.0"}])
             |> Code.eval_quoted()
  end

  test "add does not touch existing deps" do
    expected = [{:ex_doc, "~> 1.2"}]
    deps = expected |> inspect() |> MixEdit.quote_string!() |> unwrap_deps()

    assert {expected, []} ==
             deps
             |> MixEdit.add_deps([{:ex_doc, ">= 0.0.0"}])
             |> Code.eval_quoted()
  end

  defp unwrap_deps({{:__block__, _, [deps]}, _}), do: deps
end
