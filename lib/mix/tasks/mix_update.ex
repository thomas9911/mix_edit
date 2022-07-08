defmodule Mix.Tasks.Update do
  @moduledoc """
  Update dependencies with a simple command

  Usage: mix update [OPTS] [DEP...]

  When the sorted flag is set it will sort the all dependencies in mix.exs
    This can/will mess up comments that are set inside the dependency list

  OPTS:
    --version         Set the version for the DEP
    --sorted          Sort the all dependencies in mix.exs
    --in              Set the input file (default: "mix.exs")
    --out             Set the output file (default: "mix.exs")
    --umbrella        Update DEP from all apps in an umbrella project
    --apply           Run the mix command to fetch the DEP

  ## examples

  ```sh
  mix update ex_doc
  ```

  ```sh
  mix update --version ">= 0.0.0" ex_doc
  ```

  ```sh
  mix update --version "~> 1.2" jason
  ```

  ```sh
  mix update jason tzdata gettext plug timex ex_doc
  ```

  ```sh
  mix update --sorted jason tzdata gettext plug timex ex_doc
  ```

  """
  @shortdoc "Update dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    MixAdd.GeneralTask.update(args)
  end
end
