# MixEdit

Elixir mix tasks to add, remove and update dependencies from mix.exs (or Mix.Project)

Inspired by [cargo-edit](https://crates.io/crates/cargo-edit)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `mix_edit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mix_edit, "~> 0.1.0"},
    # or via github
    {:mix_edit, github: "thomas9911/mix_edit"}
  ]
end
```

Or installed globally by:

```sh
mix archive.install hex mix_edit

# or via github

mix archive.install github thomas9911/mix_edit
```

and uninstalled globally by:

```sh
mix archive.uninstall mix_edit
```

## Examples

```sh
mix edit.add ex_doc
```

```sh
mix edit.remove ex_doc
```

```sh
mix edit.update ex_doc
```

For more examples and options check the `mix help edit.add`, `mix help edit.ex_doc`, `mix help edit.update` commands
