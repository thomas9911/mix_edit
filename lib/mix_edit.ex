defmodule MixEdit do
  @moduledoc """
  Documentation for `MixEdit`.
  """

  @doc "fetch version from hex.pm or use the version set in the options"
  def fetch_version_or_option(package, opts \\ []) do
    extra_requirements =
      opts
      |> Keyword.take([:only, :org, :override, :runtime])
      |> Keyword.update(:only, [], fn only ->
        only
        |> String.split("+")
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.to_atom/1)
      end)
      |> Enum.reject(&(elem(&1, 1) in [[], nil]))

    cond do
      Keyword.has_key?(opts, :path) ->
        [path: Keyword.fetch!(opts, :path)]

      Keyword.has_key?(opts, :version) ->
        [version: Keyword.fetch!(opts, :version)]

      true ->
        Hex.start()
        auth = Mix.Tasks.Hex.auth_info(:read, auth_inline: false)

        hex_version =
          get_version_fetcher().get(extra_requirements[:org], package, auth)
          |> get_latest_package_version!(package)
          |> add_prefix()

        [version: hex_version]
    end
    |> Enum.concat(extra_requirements)
  end

  defp get_latest_package_version!({:ok, {200, %{"latest_stable_version" => version}, _}}, _) do
    version
  end

  defp get_latest_package_version!({:ok, {404, _, _}}, package) do
    Mix.raise("package `#{package}` not found")
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

    {:ok, data, comments} = Spitfire.parse_with_comments(intext, quote_opts)
    {data, comments}
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
        :update -> update_deps(current_deps, dependencies)
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
        &match?(
          :error,
          Enum.find(deps_keyword, :error, fn tuple -> elem(tuple, 0) == elem(&1, 0) end)
        )
      )

    {current_deps ++ Enum.map(dependencies, &format_dep/1), {:add, dependencies}}
  end

  @doc "remove dependencies from the dependency list"
  def remove_deps(current_deps, remove_deps) do
    to_be_removed = Enum.map(remove_deps, &elem(&1, 0))

    {new_deps, not_removed, removed} =
      Enum.reduce(current_deps, {[], to_be_removed, []}, fn x, {deps, not_removed, removed} ->
        dep_name = get_dep_name_from_quoted(x)

        if dep_name in to_be_removed do
          {deps, List.delete(not_removed, dep_name), removed ++ [dep_name]}
        else
          {deps ++ [x], not_removed, removed}
        end
      end)

    {new_deps, {:remove, not_removed, removed}}
  end

  @doc "update dependencies from the dependency list in place"
  def update_deps(current_deps, update_deps) do
    {new_deps, not_updated, updated} =
      Enum.reduce(current_deps, {[], update_deps, []}, fn x, {deps, not_updated, updated} ->
        dep_name = get_dep_name_from_quoted(x)

        case Enum.find(not_updated, :not_found, fn x -> elem(x, 0) == dep_name end) do
          :not_found ->
            {deps ++ [x], not_updated, updated}

          found ->
            {deps ++ [format_dep(found)],
             Enum.reject(not_updated, fn x -> elem(x, 0) == dep_name end), updated ++ [found]}
        end
      end)

    {new_deps, {:update, not_updated, updated}}
  end

  defp format_dep({name, requirements}) do
    case Keyword.pop(requirements, :version) do
      {nil, extra_requirements} ->
        {:__block__, [],
         [
           {{:__block__, [], [name]}, format_dep_keyword(extra_requirements)}
         ]}

      {version, []} ->
        {:__block__, [],
         [
           {{:__block__, [], [name]}, {:__block__, [delimiter: "\""], [version]}}
         ]}

      {version, extra_requirements} ->
        {:{}, [],
         [
           {:__block__, [], [name]},
           {:__block__, [], [version]},
           format_dep_keyword(extra_requirements)
         ]}
    end
  end

  defp format_dep_keyword(keyword) do
    Enum.flat_map(keyword, fn
      {:only, []} ->
        []

      {:only, value} ->
        [
          {{:__block__, [format: :keyword], [:only]},
           {:__block__, [], [Enum.map(value, &{:__block__, [], [&1]})]}}
        ]

      {:org, value} ->
        [
          {{:__block__, [format: :keyword], [:organization]},
           {:__block__, [delimiter: "\""], [value]}}
        ]

      {:override, value} ->
        [
          {{:__block__, [format: :keyword], [:override]},
           {:__block__, [delimiter: "\""], [value]}}
        ]

      {:runtime, value} ->
        [
          {{:__block__, [format: :keyword], [:runtime]}, {:__block__, [delimiter: "\""], [value]}}
        ]

      {:path, value} ->
        [
          {{:__block__, [format: :keyword], [:path]}, {:__block__, [delimiter: "\""], [value]}}
        ]
    end)
  end

  defp get_dep_name_from_quoted(quoted) do
    quoted
    |> Code.eval_quoted()
    |> elem(0)
    |> elem(0)
  end

  defp get_version_fetcher do
    Application.get_env(:mix_edit, :version_fetcher, Hex.API.Package)
  end
end
