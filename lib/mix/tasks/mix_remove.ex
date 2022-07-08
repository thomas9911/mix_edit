defmodule Mix.Tasks.Remove do
  @moduledoc """
  Remove dependencies with a simple command

  Usage: mix remove [OPTS] [DEP...]

  When the sorted flag is set it will sort the all dependencies in mix.exs
    This can/will mess up comments that are set inside the dependency list

  OPTS:
    --sorted          Sort the all dependencies in mix.exs
    --in              Set the input file (default: "mix.exs")
    --out             Set the output file (default: "mix.exs")
    --umbrella        Remove DEP from all apps in an umbrella project
    --apply           Run the mix command to remove DEP from mix.lock

  ## examples

  ```sh
  mix remove ex_doc
  ```

  ```sh
  mix remove jason tzdata gettext plug timex ex_doc
  ```

  ```sh
  mix remove --sorted jason tzdata gettext plug timex ex_doc
  ```

  """
  @shortdoc "Remove dependencies with a simple command"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    MixAdd.GeneralTask.remove(args)
  end
end
