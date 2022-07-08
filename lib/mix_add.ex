defmodule MixAdd do
  @moduledoc """
  Documentation for `MixAdd`.
  """

  @doc "fetch version from hex.pm or use the version set in the options"
  def fetch_version_or_option(package, opts \\ []) do
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

  @doc """
  Convert elixir text to quoted term
  """
  def quote_string!(intext) do
    quote_opts = [
      unescape: false,
      warn_on_unnecessary_quotes: false,
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      emit_warnings: false
    ]

    Code.string_to_quoted_with_comments!(intext, quote_opts)
  end

  @doc "Function that updates the mix.exs file (or `Mix.Project`)"
  def deps_walker({:project, _, _} = item, _, _) do
    {item, :project}
  end

  def deps_walker(
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

  def deps_walker({key, _, args} = item, {:deps_key, deps_key}, _)
      when key == deps_key and args != [] do
    {item, :deps}
  end

  def deps_walker(item, :deps, %{dependencies: dependencies, sorted: sorted, method: method}) do
    [
      {
        {:__block__, _, [:do]} = first,
        {:__block__, second_opts, [current_deps]}
      }
    ] = item

    {deps, dependencies} =
      case method do
        :add -> add_deps(current_deps, dependencies)
        :remove -> remove_deps(current_deps, dependencies)
        _ -> Mix.raise("invalid method: `#{method}`")
      end

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

  def deps_walker(item, state, _) do
    {item, state}
  end

  @doc "add dependencies to the dependency list"
  def add_deps(current_deps, additional_dependencies) do
    {deps_keyword, _} = Code.eval_quoted(current_deps)

    dependencies =
      Enum.filter(
        additional_dependencies,
        &match?(:error, Keyword.fetch(deps_keyword, elem(&1, 0)))
      )

    {current_deps ++ Enum.map(dependencies, &format_dep/1), {:add, dependencies}}
  end

  defp format_dep({name, version}) do
    {:__block__, [],
     [
       {{:__block__, [], [name]}, {:__block__, [delimiter: "\""], [version]}}
     ]}
  end

  def remove_deps(current_deps, remove_deps) do
    to_be_removed = Enum.map(remove_deps, &elem(&1, 0))

    {new_deps, not_removed} =
      Enum.reduce(current_deps, {[], to_be_removed}, fn x, {deps, not_added} ->
        {{dep_name, _opts}, _} = Code.eval_quoted(x)

        if dep_name in to_be_removed do
          {deps, List.delete(not_added, dep_name)}
        else
          {deps ++ [x], not_added}
        end
      end)

    {new_deps, {:remove, Enum.map(not_removed, &{&1, nil})}}
  end
end
