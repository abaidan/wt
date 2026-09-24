# wt

A git worktree helper for working on several branches at once without stashing,
rebuilding, or losing your place.

`wt` creates a worktree, names its branch after a GitHub issue, stores it in one
central folder, and opens it in a new iTerm2 tab with Claude Code already
running — seeded with a link to the issue. Picking, reopening and removing
worktrees all go through an `fzf` picker, which shows each worktree's pull
request and where it stands — merged ones flagged green, so finished work is
easy to clear away.

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
Prefilling claude's prompt (press enter to send it):
  Work on this GitHub issue: https://github.com/abaidan/wt/issues/1234
```

…and a new iTerm2 tab opens in that worktree running Claude Code, with the
issue link waiting in the prompt box for you to send.

## Requirements

| | |
|---|---|
| **git** | Required, with `git worktree` support. Developed against 2.54. |
| **bash** | Required. Works on macOS's system bash 3.2. |
| **macOS + iTerm2** | Required for opening tabs — the tab is driven by AppleScript. |
| **[gh](https://cli.github.com)** | Optional. Needed for the issue picker, issue-named branches, issue links, and pull request status in the `wt list` / `wt rm` pickers. Run `gh auth login` once. |
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

To install a particular release rather than the latest commit, check out its
tag first — `git checkout v0.1.0 && ./build` — and `wt --version` will say so.

## Commands

### `wt new` — create a worktree

```sh
wt new                  # pick an open issue from a list
wt new --mine           # ...only issues assigned to you
wt new 1234             # branch from issue #1234 directly
wt new my-branch-name   # branch with an explicit name, no issue
```

The branch is named `<issue>-<slugified-title>`, e.g. issue #1234 *"Add a retry
to the upload queue"* becomes `1234-add-a-retry-to-the-upload-queue`. Slugs are
lowercased, runs of non-alphanumeric characters become `-`, and the title is
capped at 50 characters.

The worktree is created at `$WT_ROOT/<repo>/<branch>`, branched from the freshly
fetched `origin/<default-branch>`, and opened in a new tab.

The same fetch also pulls the **local** base branch up to date, so the checkout
you came from doesn't drift a little further behind on every `wt new`. It is
only ever a fast-forward: if your local base has commits of its own, or its
working tree has changes the fast-forward would clobber, `wt` says so and
leaves it exactly as it was. Either way the new worktree is cut from
`origin/<base>`, so it starts current regardless. `WT_NO_PULL=1` fetches
without touching the local branch.

Issues that already have a worktree are flagged `[worktree exists]` in the
picker. Picking one anyway is fine — `wt new` opens the existing worktree
instead of failing. The match is on the issue number rather than the whole
branch name, so an issue renamed since its worktree was created still reopens
that worktree instead of starting a second one under the new slug. If only the
*branch* survives (from a `wt rm` where you kept it), the new worktree checks
that branch out rather than trying to recreate it, and a worktree whose
directory you deleted by hand is deregistered and recreated. A directory that's
in the way but isn't a registered worktree is the one case that stops with an
error, since sorting that out needs a human.

You can type an issue number that isn't in the list — it's looked up on demand —
which matters because the list is capped (see `WT_ISSUE_LIMIT`).

### `wt list` — reopen a worktree

```sh
wt list                 # pick a worktree, switch to its tab (or open one)
wt list --plain         # plain `git worktree list` output instead
```

Unlike `wt rm`, this includes the repo's main working tree, since returning to
it is a normal thing to want. The preview pane shows the worktree's path,
`git status`, recent commits, and its pull request — description included,
rendered as markdown rather than dumped as source, with headings, bold, code
and tables intact. (`gh` prints raw text and a column of empty fields when it
detects a pipe; `wt` tells it otherwise, and hands it the pane's width so the
wrapping fits.)

Each line is annotated with the state of its branch's pull request, so you can
see what is still in flight without leaving the picker:

```
  1234-add-a-retry-to-the-upload-queue   [PR #1240 open, changes requested, checks failing]
  1189-cache-the-dashboard-summary       [✓ PR #1201 merged]  [uncommitted changes]
  spike-queue-backpressure
```

The label is `#<number>` plus the PR's state — `open`, `draft`, `merged` or
`closed` — and, while it is still open, the review decision (`approved`,
`changes requested`) and its checks (`checks passing`, `checks pending`,
`checks failing`). A branch with no pull request gets no label at all.

**Merged pull requests are marked `✓` and coloured green**, because that is the
one state meaning the worktree can go without losing anything; still-open work
is yellow, uncommitted changes red, a stale entry grey. Colour is off when
output isn't a terminal, and when `NO_COLOR` is set.

The marks sit in their own column, as wide as the longest branch name in the
list, so they line up and can be read down. Typing into the picker matches the
branch name **and** the marks — so `merged` narrows the list to exactly the
worktrees that have landed. Paths are deliberately not matched: they all share
a prefix, so typing would match everything.

Nor are paths printed, unless there is something to say. `wt` puts every
worktree it creates at `$WT_ROOT/<repo>/<branch>`, so a path per row is the
same string over and over, crowding out the branch names and getting
truncated for its trouble. A worktree that *isn't* at its expected address —
the main working tree, or a directory whose name no longer matches its branch
after the issue was renamed — says where it is instead. The preview pane
always opens with the full path.

Lookups are one `gh` call per branch, run in parallel, and take roughly a
second for a handful of worktrees. They are asked for per branch rather than
read off `gh pr list` because in a busy repo the recent PRs are mostly other
people's, and a worktree branched a fortnight ago would fall off the end. Any
failure — no `gh`, not logged in, no GitHub remote — just drops the labels
silently. Set `WT_NO_PR=1` to skip the lookups entirely.

If an iTerm2 tab is already sitting in the chosen worktree, `wt` switches to
it rather than opening a second one — so the `claude` already running there
keeps its session instead of a fresh one starting beside it. Tabs are found the
same way `wt rm` finds them (by where their processes actually are), and the
tab you ran `wt list` from doesn't count. Only when no tab is in the worktree
is a new one opened. `WT_NEW_TAB=1` always opens a new tab.

`wt open` is the same picker; `wt open <branch>` skips it and opens that branch
directly. Both, like a `wt new` that finds the worktree already exists, switch
to an existing tab the same way.

### `wt rm` — remove worktrees

```sh
wt rm                   # pick one or more (tab marks several)
wt rm 1234-some-branch  # remove that one directly
```

The picker carries the same pull request labels as `wt list`, which is usually
what you want to know before deleting anything: a green `[✓ PR #1201 merged]`
is safe to clear away, a `[PR #1240 open, checks failing]` probably isn't. The
labels are repeated in the confirmation list, and `wt rm <branch>` prints the
branch's pull request before it removes anything.

The quickest way to clear out finished work is therefore `wt rm`, type
`merged`, then <kbd>Tab</kbd> through what's left and confirm.

After the selection it lists exactly what it will remove and asks once to
confirm, then asks per worktree whether to delete the local branch too. When
that's done it drops you back into the picker with what's left, so you can keep
clearing without re-running the command; <kbd>Esc</kbd> (or a blank answer in
the numbered list) is what ends it. Declining the confirmation also returns to
the picker rather than quitting.

Three safety behaviours, since removal is forced underneath:

- **Uncommitted changes** are flagged in the picker and need a separate
  confirmation before they're discarded. Declining skips that one and continues.
- **Stale entries** — worktrees whose directory you already deleted by hand —
  are flagged `[missing, stale entry]` and deregistered without prompting, since
  there's no work left to lose.
- **The main working tree is never listed**, and the worktree you're currently
  standing in is flagged and skipped rather than failing mid-run.
- **Its iTerm2 tabs are closed with it.** A tab left sitting in a directory
  that no longer exists is stranded — every command it runs fails, and a
  `claude` in it has lost the tree it was working on. Tabs are found by asking
  the kernel where each session's processes actually are, not iTerm2's
  `session.path`, which only refreshes when the shell draws a prompt and so
  still reports the old directory for a tab that has been running `claude`
  since it opened. They are closed only after the removal itself succeeds.
  `WT_KEEP_TABS=1` turns this off.

## Configuration

All optional, all environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `WT_ROOT` | `~/worktrees` | Where worktrees are stored, as `$WT_ROOT/<repo>/<branch>`. |
| `WT_BASE_BRANCH` | the repo's default branch | Branch to create new branches from. |
| `WT_CLAUDE_ARGS` | `--permission-mode auto` | Arguments passed to `claude`. Set empty for a plain `claude`. |
| `WT_NO_CLAUDE` | unset | Set to `1` to open the tab and `cd` there without launching Claude. |
| `WT_PROMPT_TEMPLATE` | `Work on this GitHub issue: {url}` | Prompt typed into Claude in a newly created issue worktree; `{url}` is replaced with the issue URL. Set empty to disable. |
| `WT_PREFILL_DELAY` | `6` | Seconds to wait for Claude to start before typing that prompt. |
| `WT_ISSUE_LIMIT` | `30` | How many issues the picker lists. |
| `WT_NO_PULL` | unset | Set to `1` so `wt new` only fetches, leaving your local base branch where it is. |
| `WT_NO_PR` | unset | Set to `1` to skip pull request lookups in the `wt list` / `wt rm` pickers. |
| `NO_COLOR` | unset | Set to anything to turn off colour in the pickers. |
| `WT_KEEP_TABS` | unset | Set to `1` to leave a removed worktree's iTerm2 tabs open. |
| `WT_NO_TAB_TITLE` | unset | Set to `1` to keep `PR #<n>` out of the tab title. |
| `WT_NEW_TAB` | unset | Set to `1` to always open a new tab when reopening a worktree, even if one is already open in it. |

### The start prompt

In a **newly created** worktree whose branch is named after an issue, the issue
URL is typed into Claude's prompt box and left there — you press enter yourself,
or edit it first, or ignore it. Nothing is submitted on your behalf.

It is typed rather than passed as an argument, via iTerm2's `write … newline no`,
which is why there's a delay: Claude needs a moment to draw its prompt box, and
anything sent before that is dropped. If the prompt lands truncated or not at
all, raise `WT_PREFILL_DELAY`.

Two deliberate limits:

- **Only new worktrees.** Reopening through `wt list`, `wt open`, or a `wt new`
  that finds an existing worktree never prefills — that session has its own
  history and the link would just be in the way.
- **Only issue-named branches.** The issue number is read off the front of the
  branch name and the URL looked up with `gh`. A branch with no leading number
  gets nothing.

### The pull request in the tab title

Once a worktree's branch has a pull request, the tab `wt` opened for it is
titled `PR #2034` between Claude's turns, so you can tell a row of tabs apart
at a glance. During a turn Claude's own title (its topic and spinner) shows as
usual; the PR title comes back when the turn ends.

It works through hooks that `wt` passes to the `claude` it starts, via
`claude --settings ~/.local/state/wt/claude-tab-title.json`, so your own Claude
Code settings are left alone. A `gh pr create` inside the session is picked up
straight away. A PR opened any other way, from the web or before the tab
existed, is found by asking GitHub at most every ten minutes until there is
one. The number is kept in the worktree's git directory and goes with it.

Only a `claude` that `wt` started gets this. It needs `gh`, and it does nothing
when `WT_NO_PR` or `WT_NO_TAB_TITLE` is set.

## Development

The source of truth is `wt` in this repo; `~/bin/wt` is an installed copy.

```sh
./build            # validate, then install if changed
./build --check    # validate only, never write
./build --diff     # show what an install would change
./build --force    # reinstall even if identical
```

`build` runs `bash -n` and then `shellcheck --severity=warning`, and refuses to
install if either fails — a broken `wt` never reaches your `PATH`. The
installed copy is stamped with `git describe` of the checkout, so `wt --version`
prints `v0.2.0` for a release and something like `v0.2.0-3-gabc1234-dirty` for
work in between. Run straight from the repo, it prints `dev`.

### Releases

Versions are git tags of the form `vMAJOR.MINOR.PATCH`, cut with `./release`:

```sh
./release              # next patch: v0.1.0 -> v0.1.1
./release minor        # next minor: v0.1.3 -> v0.2.0
./release major        # next major: v0.4.1 -> v1.0.0
./release 1.2.3        # exactly v1.2.3
./release --dry-run    # show what would be tagged, change nothing
./release --push       # also push the new tag to origin
```

It tags the current commit of `main`, and refuses unless the tree is clean,
`main` is level with `origin/main`, and `./build --check` passes. The tag is
annotated, and its message lists the commits since the previous release.

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
