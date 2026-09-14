# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal macOS dotfiles repo. There is no build/test/lint tooling — it's shell config plus a
handful of AI-powered zsh functions. Changes are applied by re-sourcing `~/.zshrc` or re-running
`install.sh`, not by any compile step.

## Common commands

- Apply changes to a running shell: `source zshrc` (or open a new terminal).
- Full (re-)install on a new machine: `./install.sh` — installs Homebrew, runs
  `brew bundle --file=Brewfile`, symlinks dotfiles into `$HOME` (backing up any existing file to
  `~/dotfiles-backup-<timestamp>/`), then sets up vim-plug and installs vim plugins.
- Add a CLI dependency: add a `brew "..."` / `cask "..."` line to `Brewfile`, then
  `brew bundle --file=Brewfile`.
- Manually test a single zsh function after editing `zshrc`: `source zshrc && <function-name> ...`
  (e.g. `source zshrc && whatdoes tar -xvf`).

## Layout

Files live flat at the repo root and are symlinked by `install.sh::link_file` to their expected
dotfile location (e.g. `zshrc` → `~/.zshrc`, `starship.toml` → `~/.config/starship.toml`,
`ghostty/config` → `~/.config/ghostty/config`). When adding a new dotfile, add both the file and a
corresponding `link_file` call in `install.sh`.

- `zshrc` — shell init (prompt, tool `eval`/`source` hooks, aliases) plus all custom functions.
- `install.sh` — idempotent bootstrap/symlink script; the only place that knows the
  repo-file → `$HOME`-path mapping.
- `Brewfile` — declarative package list consumed by `brew bundle`.
- `starship.toml`, `tmux.conf`, `vimrc`, `ghostty/config` — tool-specific configs, symlinked as-is.

## The AI functions in `zshrc`

Several zsh functions (`ai`, `explain`, `fixen`, `aicommit`, `why`, `whatdoes`) call a
self-hosted OpenAI-compatible chat endpoint (DGX Spark) rather than any Anthropic/Claude API.
They all share one shape:

1. Read `$DGX_ENDPOINT`, `$DGX_API_KEY`, `$DGX_MODEL` (sourced from the untracked
   `~/.dgx_secrets`, loaded near the top of `zshrc`).
2. Build a JSON request body with `python3 -c` (system prompt + user content), always setting
   `chat_template_kwargs.enable_thinking: False`.
3. `curl -s -m 30 "$DGX_ENDPOINT/chat/completions" -H "Authorization: Bearer $DGX_API_KEY" ...`.
4. Parse `choices[0].message.content` back out with another `python3 -c`, checking for empty
   response / parse failure before printing.

When adding a new AI-backed function, follow this exact pattern (system prompt tailored to the
task, same curl/parse/error-handling scaffold) rather than introducing a different HTTP client or
JSON approach — the whole file relies on this being consistent since there's no shared helper to
call into.

Notable function-specific behavior to preserve if touched:
- `aicommit` requires a staged (`git add`ed) diff, shows the suggested message, and prompts
  y/n before running `git commit -m`; on "no" it copies the message to the clipboard instead.
- `why` runs the given command via `eval`, always echoes its output, and only calls out to the
  model (to explain the failure) if the exit code was non-zero; it preserves and returns that
  original exit code.
- `fixen` supports `-f`/`-c`/`-e` flags for tone, falls back to clipboard (`pbpaste`) input when
  no argument is given, prints a red/green word-level diff of the change, appends a JSON line to
  `~/.fixen_history.log`, and copies the result to the clipboard.
