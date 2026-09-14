# wt

A git worktree helper for working on several branches at once without stashing,
rebuilding, or losing your place.

`wt` creates a worktree, names its branch after a GitHub issue, stores it in one
central folder, and opens it in a new iTerm2 tab with Claude Code already
running — seeded with a link to the issue. Picking, reopening and removing
worktrees all go through an `fzf` picker.

```
$ wt new
Fetching open issues...
┌─────────────────────────────────────────────────────────┬──────────────────────┐
│   issue > retry                                         │ #1234                │
│                                                         │ Add a retry to the   │
│ ▌ #1234   Add a retry to the upload queue               │ upload queue         │
│   #1240   Cache the dashboard summary query             │                      │
│                                                         │                      │
│   abaidan/wt             (enter to pick, esc to cancel) │ Opened by abaidan    │
└─────────────────────────────────────────────────────────┴──────────────────────┘
Issue #1234: Add a retry to the upload queue
Fetching latest 'main'...
Creating worktree at ~/worktrees/wt/1234-add-a-retry-to-the-upload-queue
Seeding claude with: Work on this GitHub issue: https://github.com/abaidan/wt/issues/1234
```

…and a new iTerm2 tab opens in that worktree running
`claude --permission-mode auto "Work on this GitHub issue: …"`.

## Requirements

| | |
|---|---|
| **git** | Required, with `git worktree` support. Developed against 2.54. |
| **bash** | Required. Works on macOS's system bash 3.2. |
| **macOS + iTerm2** | Required for opening tabs — the tab is driven by AppleScript. |
| **[gh](https://cli.github.com)** | Optional. Needed for the issue picker, issue-named branches, and issue links. Run `gh auth login` once. |
| **[fzf](https://github.com/junegunn/fzf)** | Optional. Gives the interactive pickers; without it every picker falls back to a numbered menu. |
| **[shellcheck](https://www.shellcheck.net)** | Optional. Used by `./build` if present. |

## Install

```sh
git clone https://github.com/abaidan/wt.git
cd wt
./build
```

`build` validates the script and installs it to `~/bin/wt`. Make sure `~/bin` is
on your `PATH`:

```sh
export PATH="$HOME/bin:$PATH"
```

Install somewhere else with `WT_INSTALL_DIR=/usr/local/bin ./build`.

## Commands

### `wt new` — create a worktree

```sh
wt new                  # pick an open issue from a list
wt new --mine           # ...only issues assigned to you
wt new 1234             # branch from issue #1234 directly
wt new my-branch-name   # branch with an explicit name, no issue
```

The branch is named `<issue>-<slugified-title>`, e.g. issue #1234 *"Add a retry
to the upload queue"* becomes
`1234-add-a-retry-to-the-upload-queue`. Slugs are lowercased, runs
of non-alphanumeric characters become `-`, and the title is capped at 50
characters.

The worktree is created at `$WT_ROOT/<repo>/<branch>`, branched from the freshly
fetched `origin/<default-branch>`, and opened in a new tab.

Issues that already have a worktree are flagged `[worktree exists]` in the
picker. Picking one anyway is fine — `wt new` opens the existing worktree
instead of failing. If only the *branch* survives (from a `wt rm` where you kept
it), the new worktree checks that branch out rather than trying to recreate it.
A directory that's in the way but isn't a registered worktree is the one case
that stops with an error, since sorting that out needs a human.

You can type an issue number that isn't in the list — it's looked up on demand —
which matters because the list is capped (see `WT_ISSUE_LIMIT`).

### `wt list` — reopen a worktree

```sh
wt list                 # pick a worktree, open it in a new tab
wt list --plain         # plain `git worktree list` output instead
```

Unlike `wt rm`, this includes the repo's main working tree, since returning to
it is a normal thing to want. The preview pane shows `git status` and recent
commits for whichever worktree is highlighted.

`wt open` is the same picker; `wt open <branch>` skips it and opens that branch
directly.

### `wt rm` — remove worktrees

```sh
wt rm                   # pick one or more (tab marks several)
wt rm 1234-some-branch  # remove that one directly
```

After the selection it lists exactly what it will remove and asks once to
confirm, then asks per worktree whether to delete the local branch too.

Three safety behaviours, since removal is forced underneath:

- **Uncommitted changes** are flagged in the picker and need a separate
  confirmation before they're discarded. Declining skips that one and continues.
- **Stale entries** — worktrees whose directory you already deleted by hand —
  are flagged `[missing, stale entry]` and deregistered without prompting, since
  there's no work left to lose.
- **The main working tree is never listed**, and the worktree you're currently
  standing in is flagged and skipped rather than failing mid-run.

## Configuration

All optional, all environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `WT_ROOT` | `~/worktrees` | Where worktrees are stored, as `$WT_ROOT/<repo>/<branch>`. |
| `WT_BASE_BRANCH` | the repo's default branch | Branch to create new branches from. |
| `WT_CLAUDE_ARGS` | `--permission-mode auto` | Arguments passed to `claude`. Set empty for a plain `claude`. |
| `WT_NO_CLAUDE` | unset | Set to `1` to open the tab and `cd` there without launching Claude. |
| `WT_PROMPT_TEMPLATE` | `Work on this GitHub issue: {url}` | Claude's first prompt on issue-named branches; `{url}` is replaced with the issue URL. Set empty for no prompt. |
| `WT_ISSUE_LIMIT` | `30` | How many issues the picker lists. |

The start prompt is derived from the branch name: a branch beginning with digits
and a hyphen is treated as issue-named, and that issue's URL is looked up with
`gh`. This applies on reopen as well as creation, so `wt list` into an issue
branch also hands Claude the link. Branches without a leading number get no
prompt.

## Development

The source of truth is `wt` in this repo; `~/bin/wt` is an installed copy.

```sh
./build            # validate, then install if changed
./build --check    # validate only, never write
./build --diff     # show what an install would change
./build --force    # reinstall even if identical
```

`build` runs `bash -n` and then `shellcheck --severity=warning`, and refuses to
install if either fails — a broken `wt` never reaches your `PATH`.

## Known rough edges

- `default_branch`'s fallback to `main` can't fire: the `||` binds to `sed`,
  which exits 0 with empty output, so a repo with no `origin/HEAD` ends up with
  an empty base branch and a confusing `git worktree add` error.
- `wt new` run from *inside* a worktree nests the new worktree under the current
  branch's directory, because the repo name is taken from the current working
  tree rather than the main one.
- A branch that merely starts with digits (`2024-cleanup`) is treated as
  issue-named, so the start prompt may link an unrelated issue #2024.

## License

MIT — see [LICENSE](LICENSE).
