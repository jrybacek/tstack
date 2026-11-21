---
name: pr-host
description: Find out whether a repo's PRs live on GitHub or Azure DevOps, and how to do each PR operation there. Use before any PR work in file-pr, babysit-pr, full-send, full-stop, modernize, takeover, council, sol-loop, or leaving-pr-comments.
---

# PR Host

Other skills say "the host" where the steps differ between GitHub and Azure
DevOps. Use this skill to pick the host and the command for each step.

## Detect the host

Run `git remote get-url origin` (or the remote the PR targets):

- `github.com` → **GitHub**.
- `dev.azure.com`, `*.visualstudio.com`, `ssh.dev.azure.com`, or
  `vs-ssh.visualstudio.com` → **Azure DevOps**. Read the organization,
  project, and repository from the URL. Decode `%20` in names.
  - `https://dev.azure.com/<org>/<project>/_git/<repo>`
  - `https://<org>.visualstudio.com/<project>/_git/<repo>`
  - `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`
  - Without a project (`.../<org>/_git/<repo>`), the project has the repo's
    name.
- Anything else: try `gh repo view` (GitHub Enterprise). If that fails, ask
  the user.

A PR URL also names its host: `github.com/<owner>/<repo>/pull/<n>`, or
`dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<n>`.

## Tools for each host

**GitHub:** the `gh` CLI. In T3 Code, prefer its `pull_request_*` tools and
`watch_pull_request`.

**Azure DevOps:** use the first route that is available:

1. The Azure DevOps MCP tools (`repo_pull_request`, `repo_pull_request_write`,
   `repo_pull_request_thread`, `repo_pull_request_thread_write`,
   `pipelines_build`). Pass the project and the repo name.
2. The Azure CLI with the `azure-devops` extension (`az repos pr ...`). Pass
   `--org https://dev.azure.com/<org>` to every command, or set it with
   `az devops configure --defaults organization=...`. Only `list` and
   `create` also take `-p <project> -r <repo>`. Commands that take `--id`
   (`show`, `update`, `policy ...`) reject them. Sign in with `az login`, or
   put a PAT in `AZURE_DEVOPS_EXT_PAT`.
3. REST through `az devops invoke` for anything the CLI lacks, such as
   threads.

If T3 Code's PR tools reject an Azure DevOps PR, use these routes instead. If
no route works, report the blocker. Do not fall back to `gh`.

## Operations

| Step | GitHub | Azure DevOps |
|---|---|---|
| Find a PR for this branch | `gh pr list --head <branch>` | `repo_pull_request` `list` with `sourceRefName: refs/heads/<branch>`, or `az repos pr list -s <branch>` |
| Read a PR | `gh pr view <n> --json ...` | `repo_pull_request` `get`, or `az repos pr show --id <n>` |
| Recent merged PRs | `gh pr list --state merged` | `az repos pr list --status completed` |
| Create a PR | `gh pr create` | `repo_pull_request_write` `create`, or `az repos pr create -s <branch> -t <base> --title ... --description ...` |
| Edit title or description | `gh pr edit <n>` | `repo_pull_request_write` `update`, or `az repos pr update --id <n> --description ...` |
| Checks | `gh pr checks <n>` | `az repos pr policy list --id <n>` (build validation, status checks, work item linking), plus `pipelines_build` runs on the source branch |
| Rerun a check | rerun the workflow | `az repos pr policy queue --id <n> --evaluation-id <id>`, or queue the pipeline again |
| Comments and threads | `gh api` GraphQL `reviewThreads` | `repo_pull_request_thread` `list` |
| Reply to a thread | `gh api` REST or GraphQL | `repo_pull_request_thread_write` `reply` |
| Resolve a thread | GraphQL `resolveReviewThread` | `repo_pull_request_thread_write` `update_status` with `Fixed`, or `WontFix` for a dismissed finding |
| Reviews | approve or request changes | votes: `10` approved, `5` approved with suggestions, `-5` waiting for author, `-10` rejected |
| Merge | `gh pr merge` with the repo's method | complete through auto-complete with an explicit merge type (see below) |
| Auto-merge | `gh pr merge --auto` | auto-complete: `repo_pull_request_write` `update` with `autoComplete: true`, `mergeStrategy`, and `bypassPolicy: false` |
| Turn off auto-merge | `gh pr merge --disable-auto` | `az repos pr update --id <n> --auto-complete false` |
| Wait for changes | `babysit-pr`'s `pr-wait`, or `watch_pull_request` in T3 Code | `babysit-pr`'s `pr-wait` |

## How Azure DevOps differs

- **Merging is "completing".** A completed PR is merged. An abandoned PR is
  closed. There is no merge queue. Pick the merge type the branch policy
  allows and recent completed PRs use: `NoFastForward` (merge), `Squash`,
  `Rebase`, or `RebaseMerge` (semi-linear). Set it explicitly every time,
  because a PR keeps the `mergeStrategy` an earlier update set:
  - Use `repo_pull_request_write` `update` with `autoComplete: true`,
    `mergeStrategy`, and `bypassPolicy: false`. It completes as soon as every
    policy passes, so stay until the host reports the PR completed.
  - Without the MCP tools, PATCH the PR through `az devops invoke` with
    `status: completed`, `lastMergeSourceCommit`, and
    `completionOptions: {mergeStrategy, bypassPolicy: false}`. This completes
    at once, so it fails while any policy is still pending. Run it only after
    the merge gate passes.
  - Do not complete with `az repos pr update --squash`. It keeps an earlier
    `mergeStrategy`, which wins over `--squash`.
- **Never bypass policies.** Don't set `bypassPolicy` or `--bypass-policy`
  to true; that is the equivalent of `--admin`. Completing can keep options
  that an earlier update set, so always pass `false` explicitly.
- **Required checks are blocking branch policies.** Build validation runs on
  the PR's merge commit. A build policy can expire when the target branch
  moves. Automatic policies queue a new build themselves; queue a manual one
  yourself (`pr-wait` says "needs action"). Reviewer policies need a human
  vote, the same as a required review on GitHub.
- **Every comment is a thread.** Threads that are `active` or `pending` are
  unresolved. `Fixed`, `WontFix`, `Closed`, and `ByDesign` are resolved. A
  "comment requirements" policy blocks completion until all threads resolve.
- **No BEHIND state.** Azure DevOps reports conflicts, not whether the branch
  is behind. Compare with `git rev-list --count HEAD..origin/<base>` after
  `git fetch`.
- **Descriptions are limited to 4000 characters.** Keep PR descriptions short.
- **Markdown has no GitHub callouts.** `> [!NOTE]` shows up as plain text.
  Use the Azure DevOps format in `leaving-pr-comments`.
- **Work items.** If the branch name, commits, or user name a work item
  (`#123`), link it when you create the PR (`workItems`, or
  `--work-items 123`). Many repos have a policy that requires one.
- **Review bots are rare.** Greptile and Macroscope usually do not run on
  Azure DevOps. CodeRabbit can. Wait only for bots that have posted on the PR.
