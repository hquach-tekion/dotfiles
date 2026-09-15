# dotfiles

Personal macOS dotfiles: shell config, tool configs, and a handful of AI-powered zsh functions
backed by a self-hosted DGX Spark endpoint.

## Install

```
./install.sh
```

Installs Homebrew packages from `Brewfile`, symlinks dotfiles into `$HOME`, and sets up vim-plug.

## Apply changes

```
source zshrc
```

## Functions

Run `commands` after sourcing `zshrc` to list these from your shell.

| Function | Usage | Description |
| --- | --- | --- |
| `dgx-info` | `dgx-info` | Show DGX Spark endpoint/model config and example curl commands |
| `dgx-models` | `dgx-models` | List models currently loaded on the DGX Spark endpoint |
| `aider-dgx` | `aider-dgx [args]` | Run aider using the DGX Spark endpoint as its model backend |
| `ai` | `ai <description>` | Generate a shell command from a plain-English description |
| `explain` | `explain <command>` | Explain what a shell command does in plain English |
| `fixen` | `fixen [-f\|-c\|-e] [text]` | Rewrite text's tone (formal/casual/empathetic); uses clipboard if no text given |
| `aicommit` | `aicommit` | Generate a commit message from the staged git diff and optionally commit |
| `why` | `why <command>` | Run a command and explain the failure if it exits non-zero |
| `whatdoes` | `whatdoes <cmd> [flag]` | Explain what a command or flag does |
| `commands` | `commands` | Show this list |
