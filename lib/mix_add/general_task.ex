defmodule MixAdd.GeneralTask do
  @moduledoc """
  GeneralTask that branches out into the seperate subtasks, Add, Remove, Update
  """

  @options [
    version: :string,
    sorted: :boolean,
    out: :string,
    in: :string,
    umbrella: :boolean,
    apply: :boolean,
    path: :string
  ]

  def add(args) do
    run(:add, args)
  end

  def remove(args) do
    # add version here so we skip the call hex
    run(:remove, args ++ ["--version", "0.0.0"])
  end

  def update(args) do
    run(:update, args)
  end

  def run(method, args) do
    {opts, args} = OptionParser.parse!(args, strict: @options)

    umbrella = Keyword.get(opts, :umbrella, false) and Mix.Project.umbrella?()
    sorted = Keyword.get(opts, :sorted, false)
    infile = Keyword.get(opts, :in, "mix.exs")
    outfile = Keyword.get(opts, :out, "mix.exs")

    dependencies =
      case args do
        [] ->
          Mix.raise("invalid arguments, needs one argument")

        [dep] ->
          [{String.to_atom(dep), MixAdd.fetch_version_or_option(dep, opts)}]

        deps ->
          Enum.map(deps, fn dep -> {String.to_atom(dep), MixAdd.fetch_version_or_option(dep)} end)
      end

    app_paths =
      if umbrella do
        Mix.Project.apps_paths()
      else
        [{nil, ""}]
      end

    changed =
      Enum.flat_map(app_paths, fn {app, path} ->
        infile = Path.join(path, infile)
        outfile = Path.join(path, outfile)

        apply_to_file(infile, outfile, %{
          dependencies: dependencies,
          sorted: sorted,
          app: app,
          method: method
        })
      end)

    if Keyword.get(opts, :apply) do
      apply_method(method, changed)
    end
  end

  defp apply_method(:add, _) do
    # sadly we cant use Mix.Task.run because Mix.Project needs to be reloaded
    # so we use another process to do this
    System.cmd("mix", ["deps.get"], into: IO.stream())
  end

  defp apply_method(:update, updated_collection) do
    updated =
      updated_collection
      |> Enum.flat_map(fn {:update, _, updated} -> updated end)
      |> Enum.map(&(&1 |> elem(0) |> to_string()))

    System.cmd("mix", ["deps.update"] ++ updated, into: IO.stream())
  end

  defp apply_method(:remove, removed_collection) do
    removed =
      removed_collection
      |> Enum.flat_map(fn {:remove, _, removed} -> removed end)
      |> Enum.map(&to_string/1)

    Mix.Task.run("deps.unlock", removed)
    Mix.Task.run("deps.clean", removed)
  end

  defp apply_to_file(infile, outfile, opts) do
    mix_exs_file = File.read!(infile)

    {out, deps_changed} = inner_apply(mix_exs_file, opts)

    File.write!(outfile, out)
    deps_changed
  end

  defp inner_apply(intext, opts) do
    app = Map.get(opts, :app)

    {quoted, comments} = MixAdd.quote_string!(intext)

    {quoted, deps_changed} =
      Macro.prewalk(
        quoted,
        nil,
        &MixAdd.deps_walker(&1, &2, opts)
      )

    print_deps_changed(deps_changed, app)

    out =
      quoted
      |> Code.Formatter.to_algebra(comments: comments)
      |> Inspect.Algebra.format(98)
      |> IO.iodata_to_binary()
      |> Code.format_string!()

    {out, [deps_changed]}
  end

  defp print_deps_changed({:add, []}, app) do
    Mix.shell().info("no new dependencies added#{to_app_message(app)}")
  end

  defp print_deps_changed({:add, deps_added}, app) do
    Enum.each(
      deps_added,
      fn {dep, info} ->
        info = Map.new(info)
        Mix.shell().info("adding `:#{dep}` #{version_or_path(info)}#{to_app_message(app)}")
      end
    )
  end

  defp print_deps_changed({:remove, [], []}, _) do
    Mix.raise("nothing removed")
  end

  defp print_deps_changed({:remove, deps_not_removed, deps_removed}, app) do
    Enum.each(
      deps_not_removed,
      fn dep ->
        Mix.shell().info("not removed `:#{dep}`#{to_app_message(app)}")
      end
    )

    Enum.each(
      deps_removed,
      fn dep ->
        Mix.shell().info("removed `:#{dep}`#{to_app_message(app)}")
      end
    )
  end

  defp print_deps_changed({:update, [], []}, app) do
    Mix.shell().info("nothing updated#{to_app_message(app)}")
  end

  defp print_deps_changed({:update, not_updated, updated}, app) do
    Enum.each(
      not_updated,
      fn {dep, _} ->
        Mix.shell().info("not updated `:#{dep}`#{to_app_message(app)}")
      end
    )

    Enum.each(
      updated,
      fn {dep, info} ->
        info = Map.new(info)
        Mix.shell().info("updated `:#{dep}` to #{version_or_path(info)}#{to_app_message(app)}")
      end
    )
  end

  defp version_or_path(%{version: version}), do: "version `#{version}`"
  defp version_or_path(%{path: path}), do: "path `#{path}`"

  defp to_app_message(nil), do: ""
  defp to_app_message(app), do: " for app `#{app}`"
end
