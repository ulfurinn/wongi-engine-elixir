defmodule Mix.Tasks.Bump do
  @shortdoc "Bumps the version, commits and tags it"
  @moduledoc """
  Bumps the project version in `mix.exs`, commits the change and tags it.

      mix bump --patch
      mix bump --minor --push

  Exactly one of `--major`, `--minor` or `--patch` is required.

  ## Options

    * `--push` - push the current branch and the new tag to `origin`,
      which triggers the Hex publish job in CI
  """

  use Mix.Task

  @switches [major: :boolean, minor: :boolean, patch: :boolean, push: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: @switches)

    part =
      case Enum.filter([:major, :minor, :patch], &opts[&1]) do
        [part] -> part
        _ -> Mix.raise("Pass exactly one of --major, --minor or --patch")
      end

    if git!(["status", "--porcelain"]) != "" do
      Mix.raise("Working tree is not clean")
    end

    old = Mix.Project.config()[:version]
    new = old |> Version.parse!() |> bump(part) |> to_string()
    tag = "v#{new}"

    if git!(["tag", "--list", tag]) != "" do
      Mix.raise("Tag #{tag} already exists")
    end

    update_mix_exs!(old, new)
    git!(["commit", "-m", "bump version", "mix.exs"])
    git!(["tag", tag])
    Mix.shell().info("Bumped #{old} -> #{new}, tagged #{tag}")

    if opts[:push] do
      branch = git!(["rev-parse", "--abbrev-ref", "HEAD"])
      git!(["push", "--atomic", "origin", branch, tag])
      Mix.shell().info("Pushed #{branch} and #{tag}")
    else
      Mix.shell().info("Run `git push --atomic origin HEAD #{tag}` to publish")
    end
  end

  defp bump(v, :major), do: %Version{major: v.major + 1, minor: 0, patch: 0}
  defp bump(v, :minor), do: %Version{major: v.major, minor: v.minor + 1, patch: 0}
  defp bump(v, :patch), do: %Version{major: v.major, minor: v.minor, patch: v.patch + 1}

  defp update_mix_exs!(old, new) do
    content = File.read!("mix.exs")
    pattern = ~s(version: "#{old}")

    case String.split(content, pattern) do
      [before, rest] -> File.write!("mix.exs", before <> ~s(version: "#{new}") <> rest)
      _ -> Mix.raise(~s(Expected exactly one #{pattern} in mix.exs))
    end
  end

  defp git!(args) do
    case System.cmd("git", args, stderr_to_stdout: true) do
      {out, 0} -> String.trim(out)
      {out, _} -> Mix.raise("git #{Enum.join(args, " ")} failed:\n#{out}")
    end
  end
end
