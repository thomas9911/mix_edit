defmodule Mix.Tasks.Edit.Add do
  @moduledoc """
  Add dependencies with a simple command

  Usage: mix edit.add [OPTS] [DEP...]

  When the version is not specified will get the latest version from hex.
    Setting the version only works when you add one dependency
  When the sorted flag is set it will sort the all dependencies in mix.exs
    This can/will mess up comments that are set inside the dependency list

  OPTS:
    --version         Set the version for the DEP
    --path            Set the path for the DEP
    --sorted          Sort the all dependencies in mix.exs
    --in              Set the input file (default: "mix.exs")
    --out             Set the output file (default: "mix.exs")
    --umbrella        Add DEP to all apps in an umbrella project
    --apply           Run the mix command to fetch the DEP
    --only            Setting the only flag, example 'test' or 'test+dev'

  ## examples

  ```sh
  mix edit.add ex_doc
  ```

  ```sh
  mix edit.add --version ">= 0.0.0" ex_doc
  ```

  ```sh
  mix edit.add --version "~> 1.2" jason
  ```

  ```sh
  mix edit.add jason tzdata gettext plug timex ex_doc
  ```

  ```sh
  mix edit.add --sorted jason tzdata gettext plug timex ex_doc
  ```

  """
  @shortdoc "Add dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    MixEdit.GeneralTask.add(args)
  end
end
