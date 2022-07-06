defmodule Mix.Tasks.Add do
  @moduledoc """
  Add dependencies with a simple command

  Usage: mix add [OPTS] [DEP...]

  When the version is not specified will get the latest version from hex.
    Setting the version only works when you add one dependency
  When the sorted flag is set it will sort the all dependencies in mix.exs
    This can/will mess up comments that are set inside the dependency list

  OPTS:
    --version         Set the version for the DEP
    --sorted          Sort the all dependencies in mix.exs
    --in              Set the input file (default: "mix.exs")
    --out              Set the output file (default: "mix.exs")

  ## examples

  ```sh
  mix add ex_doc
  ```

  ```sh
  mix add --version ">= 0.0.0" ex_doc
  ```

  ```sh
  mix add --version "~> 1.2" jason
  ```

  ```sh
  mix add jason tzdata gettext plug timex ex_doc
  ```

  ```sh
  mix add --sorted jason tzdata gettext plug timex ex_doc
  ```

  """
  @shortdoc "Add dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, args} =
      OptionParser.parse!(args,
        strict: [version: :string, sorted: :boolean, out: :string, in: :string]
      )

    sorted = Keyword.get(opts, :sorted, false)
    infile = Keyword.get(opts, :in, "mix.exs")
    outfile = Keyword.get(opts, :out, "mix.exs")

    dependencies =
      case args do
        [] ->
          Mix.raise("invalid arguments, needs one argument")

        [dep] ->
          [{String.to_atom(dep), fetch_version_or_option(opts, dep)}]

        deps ->
          Enum.map(deps, fn dep -> {String.to_atom(dep), fetch_version_or_option([], dep)} end)
      end

    mix_exs_file = File.read!(infile)

    opts = [
      unescape: false,
      warn_on_unnecessary_quotes: false,
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      emit_warnings: false
    ]

    {quoted, comments} = Code.string_to_quoted_with_comments!(mix_exs_file, opts)

    {quoted, deps_added} =
      Macro.prewalk(
        quoted,
        nil,
        &deps_walker(&1, &2, %{dependencies: dependencies, sorted: sorted})
      )

    print_deps_added(deps_added)

    out =
      quoted
      |> Code.Formatter.to_algebra(comments: comments)
      |> Inspect.Algebra.format(98)
      |> IO.iodata_to_binary()
      |> Code.format_string!()

    File.write!(outfile, out)
  end

  defp print_deps_added([]) do
    Mix.shell().info("no new dependencies added")
  end

  defp print_deps_added(deps_added) do
    Enum.each(
      deps_added,
      fn {dep, version} ->
        Mix.shell().info("adding `:#{dep}` with version `#{version}`")
      end
    )
  end

  defp fetch_version_or_option(opts, package) do
    case Keyword.fetch(opts, :version) do
      {:ok, version} ->
        version

      _ ->
        Hex.start()
        auth = Mix.Tasks.Hex.auth_info(:read, auth_inline: false)

        Hex.API.Package.get(nil, package, auth)
        |> get_latest_package_version!()
        |> add_prefix()
    end
  end

  defp get_latest_package_version!({:ok, {200, %{"latest_stable_version" => version}, _}}) do
    version
  end

  defp add_prefix(version) do
    "~> #{version}"
  end

  defp deps_walker({:project, _, _} = item, _, _) do
    {item, :project}
  end

  defp deps_walker(
         [{{:__block__, _, [:do]}, {:__block__, _, [project_keyword]}}] = item,
         :project,
         _
       ) do
    # find deps function name
    [deps_key] =
      Enum.flat_map(project_keyword, fn
        {{:__block__, _, [:deps]}, {deps_key, _, []}} -> [deps_key]
        _ -> []
      end)

    {item, {:deps_key, deps_key}}
  end

  defp deps_walker({key, _, args} = item, {:deps_key, deps_key}, _)
       when key == deps_key and args != [] do
    {item, :deps}
  end

  defp deps_walker(item, :deps, %{dependencies: dependencies, sorted: sorted}) do
    [
      {
        {:__block__, _, [:do]} = first,
        {:__block__, second_opts, [deps]}
      }
    ] = item

    {deps_keyword, _} = Code.eval_quoted(deps)

    dependencies =
      Enum.filter(dependencies, &match?(:error, Keyword.fetch(deps_keyword, elem(&1, 0))))

    deps = deps ++ Enum.map(dependencies, &format_dep/1)

    deps =
      if sorted do
        Enum.sort_by(deps, fn {_, _, [{{_, _, [dep]}, _}]} -> dep end)
      else
        deps
      end

    {[
       {
         {:__block__, _, [:do]} = first,
         {:__block__, second_opts, [deps]}
       }
     ], dependencies}
  end

  defp deps_walker(item, state, _) do
    {item, state}
  end

  defp format_dep({name, version}) do
    {:__block__, [],
     [
       {{:__block__, [], [name]}, {:__block__, [delimiter: "\""], [version]}}
     ]}
  end
end
