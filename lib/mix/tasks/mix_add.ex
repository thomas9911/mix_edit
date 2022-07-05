defmodule Mix.Tasks.Add do
  @moduledoc """
  Add dependencies with a simple command

  When the version is not specified will get the latest version from hex.

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
  """
  @shortdoc "Add dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: [version: :string])

    dependencies =
      case args do
        [] ->
          Mix.raise("invalid arguments, needs one argument")

        [dep] ->
          [{String.to_atom(dep), fetch_version_or_option(opts, dep)}]

        deps ->
          Enum.map(deps, fn dep -> {String.to_atom(dep), fetch_version_or_option([], dep)} end)
      end

    Enum.each(
      dependencies,
      fn {dep, version} ->
        Mix.shell().info("adding `:#{dep}` with version `#{version}`")
      end
    )

    mix_exs_file = File.read!("mix.exs")

    opts = [
      unescape: false,
      warn_on_unnecessary_quotes: false,
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      emit_warnings: false
    ]

    {quoted, comments} = Code.string_to_quoted_with_comments!(mix_exs_file, opts)

    {quoted, _} = Macro.prewalk(quoted, nil, &deps_walker(&1, &2, dependencies))

    out =
      quoted
      |> Code.Formatter.to_algebra(comments: comments)
      |> Inspect.Algebra.format(98)
      |> IO.iodata_to_binary()
      |> Code.format_string!()

    File.write!("mix.exs", out)
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

  defp deps_walker({:deps, _, nil} = item, _, _) do
    {item, :deps}
  end

  defp deps_walker(item, :deps, dependencies) do
    [
      {
        {:__block__, _, [:do]} = first,
        {:__block__, second_opts, [deps]}
      }
    ] = item

    deps = deps ++ Enum.map(dependencies, &format_dep/1)

    {[
       {
         {:__block__, _, [:do]} = first,
         {:__block__, second_opts, [deps]}
       }
     ], nil}
  end

  defp deps_walker(item, _, _) do
    {item, nil}
  end

  defp format_dep({name, version}) do
    {:__block__, [],
     [
       {{:__block__, [], [name]}, {:__block__, [delimiter: "\""], [version]}}
     ]}
  end
end
