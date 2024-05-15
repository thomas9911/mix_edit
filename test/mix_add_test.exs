defmodule MixEditTest do
  use ExUnit.Case, async: true
  doctest MixEdit

  describe "fetch_version_or_option" do
    test "fetches from hex" do
      assert [version: "~> 735.7"] == MixEdit.fetch_version_or_option("testing")
    end

    test "not exists raises" do
      assert_raise(Mix.Error, "package `not_existing` not found", fn ->
        MixEdit.fetch_version_or_option("not_existing")
      end)
    end

    test "fetches from hex with options" do
      assert [
               version: "~> 1.23",
               override: true,
               runtime: false,
               only: [:test, :dev, :prod],
               org: "myorg"
             ] ==
               MixEdit.fetch_version_or_option("testing",
                 override: true,
                 runtime: false,
                 only: "test+dev+prod",
                 org: "myorg",
                 extra_fields: :ignored
               )
    end

    test "from version" do
      assert [version: ">= 0.0.0"] ==
               MixEdit.fetch_version_or_option("testing", version: ">= 0.0.0")
    end

    test "from path" do
      assert [path: "../../testing"] ==
               MixEdit.fetch_version_or_option("testing", path: "../../testing")
    end

    test "from path with options" do
      assert [
               path: "../../testing",
               override: true,
               runtime: false,
               only: [:test],
               org: "myorg"
             ] ==
               MixEdit.fetch_version_or_option("testing",
                 path: "../../testing",
                 override: true,
                 runtime: false,
                 only: "test",
                 org: "myorg",
                 extra_fields: :ignored
               )
    end
  end

  describe "add_deps" do
    test "adds new dependency" do
      expected = [{:ex_doc, ">= 0.0.0"}]

      deps =
        []
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:add, [ex_doc: [version: ">= 0.0.0"]]}} =
               MixEdit.add_deps(deps, [{:ex_doc, [version: ">= 0.0.0"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end

    test "appends new dependency" do
      expected = [{:ex_doc, ">= 0.0.0"}, {:plug, "~> 1.0"}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:add, [plug: [version: "~> 1.0"]]}} =
               MixEdit.add_deps(deps, [{:plug, [version: "~> 1.0"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end

    test "add does not touch existing deps" do
      expected = [{:ex_doc, "~> 1.2"}]

      deps =
        expected
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:add, []}} = MixEdit.add_deps(deps, [{:ex_doc, [version: ">= 0.0.0"]}])
      assert {expected, []} == Code.eval_quoted(new_list)
    end
  end

  describe "remove_deps" do
    test "remove dependency" do
      expected = [{:ex_doc, ">= 0.0.0"}]

      deps =
        [{:ex_doc, ">= 0.0.0"}, {:plug, "~> 1.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:remove, [], [:plug]}} =
               MixEdit.remove_deps(deps, [{:plug, [version: "0.0.0"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end

    test "does nothing if not in list" do
      expected = [{:ex_doc, ">= 0.0.0"}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:remove, [:plug], []}} =
               MixEdit.remove_deps(deps, [{:plug, [version: "0.0.0"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end
  end

  describe "update_deps" do
    test "version" do
      expected = [{:ex_doc, "~> 1.0"}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:update, [], [ex_doc: [version: "~> 1.0"]]}} =
               MixEdit.update_deps(deps, [{:ex_doc, [version: "~> 1.0"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end
  end

  describe "options formatted" do
    test "version with organisation" do
      expected = [{:ex_doc, "~> 1.0", [organization: "myorg"]}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:update, [], [ex_doc: [version: "~> 1.0", org: "myorg"]]}} =
               MixEdit.update_deps(deps, [{:ex_doc, [version: "~> 1.0", org: "myorg"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end

    test "path" do
      expected = [{:ex_doc, [path: "../../ex_doc"]}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list, {:update, [], [ex_doc: [path: "../../ex_doc"]]}} =
               MixEdit.update_deps(deps, [{:ex_doc, [path: "../../ex_doc"]}])

      assert {expected, []} == Code.eval_quoted(new_list)
    end

    test "options" do
      expected = [{:ex_doc, "~> 1.0", [override: true, runtime: false]}]

      deps =
        [{:ex_doc, ">= 0.0.0"}]
        |> inspect()
        |> MixEdit.quote_string!()
        |> unwrap_deps()

      assert {new_list,
              {:update, [], [ex_doc: [version: "~> 1.0", override: true, runtime: false]]}} =
               MixEdit.update_deps(deps, [
                 {:ex_doc, [version: "~> 1.0", override: true, runtime: false]}
               ])

      assert {expected, []} == Code.eval_quoted(new_list)
    end
  end

  describe "sorting the dependency list works" do
    test "simple" do
      mix_project = """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [
            version: "0.1.0",
            start_permanent: Mix.env() == :prod,
            deps: deps()
          ]
        end

        defp deps do
          [
            {:jason, "~> 0.0.0"},
            {:ex_doc, ">= 0.0.0"},
            {:sweet_xml, ">= 0.0.0"}
          ]
        end
      end
      """

      assert mix_project_sort(mix_project, testing: [version: ">= 0.0.0"]) =~
               "defp deps do [{:ex_doc, \">= 0.0.0\"}, {:jason, \"~> 0.0.0\"}, {:sweet_xml, \">= 0.0.0\"}, {:testing, \">= 0.0.0\"}] end"
    end

    test "extra tags" do
      mix_project = """
      defmodule MoreTags.MixProject do
        use Mix.Project

        @dev_envs [:dev, :test]

        def project do
          [
            version: "0.1.0",
            start_permanent: Mix.env() == :prod,
            deps: deps()
          ]
        end

        # Run "mix help deps" to learn about dependencies.
        defp deps do
          [
            {:jason, "~> 1.0"},
            {:credo, "~> 1.7.1", only: [:dev]},
            {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
            {:excoveralls, "~> 0.17", only: @dev_envs},
          ]
        end
      end

      """

      assert mix_project_sort(mix_project, testing: [version: ">= 0.0.0"]) =~
               Enum.join([
                 "deps do [{:credo, \"~> 1.7.1\", only: [:dev]}, {:dialyxir, \"~> 1.4\", only: [:dev], runtime: false}, ",
                 "{:excoveralls, \"~> 0.17\", only: @dev_envs}, {:jason, \"~> 1.0\"}, {:testing, \">= 0.0.0\"}] end"
               ])
    end
  end

  defp mix_project_sort(mix_project, deps) do
    opts = %{
      dependencies: deps,
      sorted: true,
      app: :test,
      method: :add
    }

    {quoted, comments} = MixEdit.quote_string!(mix_project)

    {new_file, info} =
      Macro.prewalk(
        quoted,
        nil,
        &MixEdit.deps_walker(&1, &2, opts)
      )

    assert {:add, [testing: [version: ">= 0.0.0"]]} == info

    new_file
    |> Code.Formatter.to_algebra(comments: comments)
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
  end

  defp unwrap_deps({{:__block__, _, [deps]}, _}), do: deps
end
