defmodule MixAdd.GeneralTask do
  @moduledoc """
  GeneralTask that branches out into the seperate subtasks, Add, Remove, Update
  """

  @options [version: :string, sorted: :boolean, out: :string, in: :string, umbrella: :boolean]

  def add(args) do
    run(:add, args)
  end

  def remove(args) do
    run(:remove, args ++ ["--version", "0.0.0"])
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

    Enum.each(app_paths, fn {app, path} ->
      infile = Path.join(path, infile)
      outfile = Path.join(path, outfile)

      apply_to_file(infile, outfile, %{
        dependencies: dependencies,
        sorted: sorted,
        app: app,
        method: method
      })
    end)
  end

  defp apply_to_file(infile, outfile, opts) do
    mix_exs_file = File.read!(infile)

    out = inner_apply(mix_exs_file, opts)

    File.write!(outfile, out)
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

    quoted
    |> Code.Formatter.to_algebra(comments: comments)
    |> Inspect.Algebra.format(98)
    |> IO.iodata_to_binary()
    |> Code.format_string!()
  end

  defp print_deps_changed({:add, []}, nil) do
    Mix.shell().info("no new dependencies added")
  end

  defp print_deps_changed({:add, []}, app) do
    Mix.shell().info("no new dependencies added for app `#{app}`")
  end

  defp print_deps_changed({:add, deps_added}, app) do
    Enum.each(
      deps_added,
      fn {dep, version} ->
        if app do
          Mix.shell().info("adding `:#{dep}` with version `#{version}` for app `#{app}`")
        else
          Mix.shell().info("adding `:#{dep}` with version `#{version}`")
        end
      end
    )
  end

  defp print_deps_changed({:remove, []}, nil) do
    Mix.shell().info("all dependencies removed")
  end

  defp print_deps_changed({:remove, []}, app) do
    Mix.shell().info("all dependencies removed for app `#{app}`")
  end

  defp print_deps_changed({:remove, deps_added}, app) do
    Enum.each(
      deps_added,
      fn {dep, _} ->
        if app do
          Mix.shell().info("not removed `:#{dep}` for app `#{app}`")
        else
          Mix.shell().info("not removed `:#{dep}`")
        end
      end
    )
  end
end
