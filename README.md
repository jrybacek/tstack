# tstack

The agent skills I use every day, cleaned up so anyone can use them. They work
in Claude Code and Codex. Some use [T3 Code](https://github.com/pingdotgg/t3code)
features when they are available and fall back to native tools when they are
not. The PR skills work with repos on GitHub and on Azure DevOps, and pick the
host from the repo's `origin` remote.

## Skills

| Skill | Say | What it does |
|---|---|---|
| `full-send` | "full send" | Takes a change to a merged PR with nobody watching: proves it, reviews it, files it, babysits it, merges it. |
| `full-stop` | "full stop" | Same as `full-send`, but stops when the PR is ready for you to merge. |
| `council` | "council" | Gets review from three models from different providers, and loops until they agree. |
| `sol-loop` | "sol loop" | Reviews a change with GPT Sol in a loop until both agents agree. |
| `file-pr` | "file a PR" | Files a short PR that leads with the problem, not an inventory of changes. |
| `takeover` | "take over" | Finishes someone else's PR, branch, or agent thread, and keeps their credit. |
| `babysit-pr` | "babysit" | Watches a PR through CI and review bots, and fixes the real findings. |
| `modernize` | "modernize" | Rebases an old PR and decides if it should still exist. |
| `leaving-pr-comments` | (automatic) | Formats comments that an agent posts on your behalf. |
| `pr-host` | (automatic) | Detects whether a repo is on GitHub or Azure DevOps, and maps each PR step to that host. |

Some skills call others. Install the ones they need too:

- `full-send` uses `sol-loop`, `file-pr`, and `babysit-pr`.
- `full-stop` uses `full-send`.
- `takeover` uses `modernize`, `file-pr`, `babysit-pr`, and `leaving-pr-comments`.
- `file-pr`, `babysit-pr`, and `modernize` use `leaving-pr-comments`.
- Every PR skill uses `pr-host`.

If you're unsure, install them all.

## Install

Clone the repo, then copy the skills into your harness's skills folder.

Windows (PowerShell), or anywhere PowerShell 7 runs:

```powershell
git clone https://github.com/jrybacek/tstack
./tstack/install.ps1 -WhatIf   # show what would be installed, change nothing
./tstack/install.ps1           # install
```

`install.ps1` installs for Claude Code and Codex only if they are installed:
their command (`claude`, `codex`) is on PATH, or their folder (`~/.claude`,
`~/.codex`) exists. Pick harnesses or skills with
`-Harness Claude` or `-Skill babysit-pr, pr-host`. If Windows blocks the
script, run `powershell -ExecutionPolicy Bypass -File .\tstack\install.ps1`.

macOS and Linux without PowerShell:

```bash
git clone https://github.com/jrybacek/tstack
mkdir -p ~/.claude/skills && cp -R tstack/skills/* ~/.claude/skills/   # Claude Code
mkdir -p ~/.codex/skills && cp -R tstack/skills/* ~/.codex/skills/     # Codex
```

To update, run `git -C tstack pull --ff-only` instead of `git clone`, then
install again. Updating copies the repo's files over the installed ones. Files
the repo has since deleted stay behind; delete that skill's folder first for a
clean copy.

Check that the skills are in place:

```bash
ls ~/.claude/skills/*/SKILL.md ~/.codex/skills/*/SKILL.md   # macOS and Linux
```

```powershell
Get-ChildItem "$HOME\.claude\skills\*\SKILL.md", "$HOME\.codex\skills\*\SKILL.md"   # Windows
```

If a skill doesn't show up in a session that was already open, start a new
session.

## Requirements

- For GitHub repos: an authenticated [GitHub CLI](https://cli.github.com)
  (`gh auth login`).
- For Azure DevOps repos: the
  [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) with the
  `azure-devops` extension (`az extension add --name azure-devops`), signed in
  with `az login` or a PAT in `AZURE_DEVOPS_EXT_PAT`. Agents also use the
  [Azure DevOps MCP server](https://github.com/microsoft/azure-devops-mcp)
  when it is connected.
- Python 3.9 or later for `babysit-pr`'s `pr-wait` script. On Windows, agents
  run it as `python <path>\pr-wait`, or `py -3 <path>\pr-wait` if `python`
  opens the Microsoft Store.
- `council` and `sol-loop` need subagents on other providers' models. T3 Code
  does this with `delegate_task`. Otherwise you need a harness that can run
  those models.

## Make them yours

These are starting points. Edit them. Put personal settings, like which models
sit on your council, in your `CLAUDE.md` or `AGENTS.md`, so you can update the
skills without losing them.

## License

[MIT](LICENSE)
