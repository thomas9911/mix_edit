defmodule Mix.Tasks.Edit.Update do
  @moduledoc """
  Update dependencies with a simple command

  Usage: mix edit.update [OPTS] [DEP...]

  When the sorted flag is set it will sort the all dependencies in mix.exs
    This can/will mess up comments that are set inside the dependency list

  OPTS:
    --version         Set the version for the DEP
    --path            Set the path for the DEP
    --sorted          Sort the all dependencies in mix.exs
    --in              Set the input file (default: "mix.exs")
    --out             Set the output file (default: "mix.exs")
    --umbrella        Update DEP from all apps in an umbrella project
    --only            Setting the only flag, example 'test' or 'test+dev'
    --override        Set the override option
    --no-runtime      Set the runtime option to false
    --apply           Run the mix command to fetch the DEP

  ## examples

  ```sh
  mix edit.update ex_doc
  ```

  ```sh
  mix edit.update --version ">= 0.0.0" ex_doc
  ```

  ```sh
  mix edit.update --version "~> 1.2" jason
  ```

  ```sh
  mix edit.update jason tzdata gettext plug timex ex_doc
  ```

  ```sh
  mix edit.update --sorted jason tzdata gettext plug timex ex_doc
  ```

  """
  @shortdoc "Update dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    MixEdit.GeneralTask.update(args)
  end
end
