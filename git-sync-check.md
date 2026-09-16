# Checking if local and remote branches are in sync

A quick, safe workflow to confirm your local branch matches the remote (e.g. GitHub) before
trusting `git log`/`git status` output. Works in any git repo.

## 1. Update your knowledge of the remote

```sh
git fetch origin
```

`fetch` downloads new commits/branches from the remote but does **not** touch your working
files or local branch — it only updates your local record of where the remote is
(`origin/main`, etc). Always run this before comparing, since that record goes stale as soon as
anyone else pushes.

Contrast with `git pull`, which is `fetch` + `merge` (or rebase) in one step — it fetches *and*
immediately integrates those changes into your current branch, touching your working files.
Use `fetch` when you just want to look; use `pull` when you're ready to update your branch.

## 2. Quick check

```sh
git status -sb
```

- `-s` = short format (compact, one line per changed file)
- `-b` = show branch tracking info

Look at the first line: `## main...origin/main` with nothing else appended means you're fully in
sync. If there's a divergence, git appends `[ahead N]`, `[behind N]`, or `[ahead N, behind N]`.

## 3. Exact confirmation (compare commit hashes)

```sh
git rev-parse HEAD          # local commit
git rev-parse origin/main   # remote commit (as of last fetch)
```

If both print the same SHA, your local branch and the remote are identical.

## 4. Cross-check via GitHub CLI (optional)

```sh
gh repo view --json defaultBranchRef -q .defaultBranchRef.name   # confirm default branch name
gh api repos/{owner}/{repo}/commits/main --jq .sha                # remote HEAD sha via GitHub API
```

Compare that SHA to `git rev-parse HEAD` for a check that doesn't rely on your local git's cached
remote state at all.

## TL;DR

```sh
git fetch origin && git status -sb
```

One line, safe to run anytime, tells you immediately if you're ahead, behind, diverged, or in
sync.
