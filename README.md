# wt

A git worktree helper for working on several branches at once without stashing,
rebuilding, or losing your place.

`wt` creates a worktree, names its branch after a GitHub issue or a Jira ticket
(or checks out a pull request's branch), stores it in one central folder, and
opens it in a new iTerm2 tab with Claude Code already running — seeded with a
link to the issue, ticket or pull request. Run plain `wt` and one `fzf` picker
holds everything: a tab each for issues, pull requests, Jira tickets and
worktrees, where <kbd>Enter</kbd> takes you to the work — creating its worktree
first if there isn't one yet — and each worktree shows its pull request and
what the `claude` in it is doing, merged ones flagged green so finished work is
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
  Work on this GitHub issue: https://github.com/abaidan/wt/issues/1234 Open PR, watch bots.
```

…and a new iTerm2 tab opens in that worktree running Claude Code, with the
issue link waiting in the prompt box for you to send.

## Requirements

| | |
|---|---|
| **git** | Required, with `git worktree` support. Developed against 2.54. |
| **bash** | Required. Works on macOS's system bash 3.2. |
| **macOS + iTerm2** | Required for opening tabs — the tab is driven by AppleScript. |
| **iTerm2 3.7+** | Optional. Its `it2` command lets the pickers show which worktrees have a tab open, and what the `claude` in it is doing; that part also needs iTerm2's Claude Code integration (iTerm2 › Install Claude Code Integration). Without either, those marks are left out. |
| **[gh](https://cli.github.com)** | Optional. Needed for the issue and pull request pickers, issue-named branches, issue links, and pull request status in the `wt list` / `wt rm` pickers. Run `gh auth login` once. |
| **curl + [jq](https://jqlang.org)** | Optional. Needed for Jira tickets. curl ships with macOS; `brew install jq`. |
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

### `wt` — the picker

```sh
wt                      # open the picker on the Issues tab
```

```
╭  Issues 12    Pull requests 11    Jira 4    Worktrees 15   ────────────────────╮
│ issues >                                                                      │
│   tab next view · enter open or create · alt-m only mine · esc quit           │
│ ▌ #242                                OTLP gateway dashboard: traffic in do…  │
│   #187    [waiting]   #301 open ✗     VB365 controller log lines are ingest…  │
│   #186                                Recording rules for the VB365 Tenant S… │
╰───────────────────────────────────────────────────────────────────────────────╯
```

| Key | What it does |
|---|---|
| <kbd>Tab</kbd> / <kbd>⇧Tab</kbd> | Next / previous tab: Issues, Pull requests, Jira (when set up), Worktrees |
| <kbd>Enter</kbd> | Go to it: switch to the worktree's iTerm2 tab, or open one — and for an issue, pull request or ticket with no worktree yet, create it first, exactly as `wt new` does. The picker stays open in its own tab, ready for the next one; only an error waits for a key |
| <kbd>alt-m</kbd> | Only mine: issues assigned to you, pull requests you opened, tickets assigned to you. Press again for everyone's |
| <kbd>ctrl-space</kbd> | Mark a worktree, to remove several at once |
| <kbd>ctrl-x</kbd> | On the Worktrees tab: remove the marked worktrees, or the one under the cursor, with the same questions as `wt rm`; then back to the picker |
| <kbd>Esc</kbd> | Quit the picker |

Issues, pull requests and tickets that have a worktree carry a mark saying so:
`[worktree]`, or — once iTerm2 can tell — what its tab is doing: `[waiting]`
for a `claude` waiting on you, `[working]`, `[tab open]`. Type `waiting` to see
just those. An issue or ticket whose worktree's branch has a pull request also
shows it in the next column: its number, its state (`open`, `draft`,
`approved`, `changes`, `merged`, `closed`) and its checks — `✓` passing, `✗`
failing, `…` pending. That column comes from the Worktrees tab's pull request
check, so it fills in when that does. The Worktrees tab is the list described under `wt list` below.

The picker never waits for the network. What each source returned last time
is kept in `~/.cache/wt/<repo>` (or under `$XDG_CACHE_HOME`), so the lists are
there the moment it opens, and every source is refreshed in the background
straight away: the tab strip shows `...` against a tab while that is under
way, and the list redraws itself when the refresh lands — through fzf's
`--listen` port, behind a key made for that run. Switching tabs shows the
rows last drawn for the tab and redraws only if something has changed since,
so it is immediate however many worktrees there are. A tab with nothing
cached yet says it is loading; a source that fails says why in its own tab —
a Jira token that has been rejected, say — without holding up the others.

The same goes for the slow parts of the Worktrees tab: the pull request
labels and which worktrees have uncommitted changes (asked of git eight
worktrees at a time) come from the last run and are brought up to date in
the background. Deleting the cache directory is always safe.

`wt new`, `wt list` and `wt open` with nothing named open this same picker, on
the tab they're about. Without fzf there are no tabs, and each command falls
back to its own numbered menu.

### `wt new` — create a worktree

```sh
wt new                  # the picker, on the Issues tab
wt new --mine           # ...only issues assigned to you
wt new 1234             # branch from issue #1234 directly
wt new --pr             # the picker, on the Pull requests tab
wt new --pr --mine      # ...only pull requests you opened
wt new --pr 1240        # check out pull request #1240 directly
wt new --jira           # the picker, on the Jira tab
wt new --jira --mine    # ...only tickets assigned to you
wt new SRE-1234         # branch from Jira ticket SRE-1234 directly
wt new <link>           # any of the above from a pasted GitHub issue or pull
                        # request link, or a Jira /browse/ link
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

Issues that already have a worktree are flagged `[worktree]` in the
picker (or with what their tab is doing, as above). Picking one anyway is fine — `wt new` opens the existing worktree
instead of failing. The match is on the issue number rather than the whole
branch name, so an issue renamed since its worktree was created still reopens
that worktree instead of starting a second one under the new slug. If only the
*branch* survives (from a `wt rm` where you kept it), the new worktree checks
that branch out rather than trying to recreate it, and a worktree whose
directory you deleted by hand is deregistered and recreated. A directory that's
in the way but isn't a registered worktree is the one case that stops with an
error, since sorting that out needs a human.

The picker loads every open issue (up to `WT_ISSUE_LIMIT`), so typing in fzf
searches all of them, not just the newest. Without fzf, the numbered menu prints
only the newest 50. You can still type any issue number, listed or not, and it's
looked up on demand.

#### Pull requests

`wt new --pr` checks out the pull request's **own** branch rather than cutting
a new one, so commits made there land in the pull request when pushed. The
worktree is named after that branch, which means a pull request opened from a
`wt new` worktree comes back to that same worktree instead of a second copy —
and the picker flags it `[worktree]`, as for issues. A local copy of the branch
left from earlier is fast-forwarded to the pull request first, but never moved
if it has commits of its own.

A pull request from a fork has no branch in this repo to share. It gets a local
`pr-<number>-<branch>`, cut from the copy GitHub keeps under
`refs/pull/<number>/head`, with no upstream: fine for reviewing and trying it
out, but pushing back needs a remote for the fork.

A pasted link to some other repo's issue or pull request is refused, rather
than its number looked up here and an unrelated item found.

#### Jira tickets

Jira Cloud, through its REST API with an
[API token](https://id.atlassian.com/manage-profile/security/api-tokens). Set
the site, and keep the token in the login keychain rather than a shell profile:

```sh
export WT_JIRA_URL=https://example.atlassian.net
export WT_JIRA_PROJECT=SRE            # optional, see below
# copy the token, then:
security add-generic-password -U -s wt-jira -a you@example.com -w "$(pbpaste)"
```

Store it from the clipboard like that, not at the prompt a bare `-w` gives:
that prompt reads at most 128 characters, and a Jira token is about 190, so
it is cut short without a word and Jira answers 401. `wt` recognises a token
of exactly 128 characters and says so. Passing `"$(pbpaste)"` keeps the token
itself out of your shell history.

The account is `git config --global user.email` — the global one, not a repo's own — unless `WT_JIRA_EMAIL` says otherwise.
`WT_JIRA_TOKEN` works too, in place of the keychain. The token is handed to
curl through a pipe, so it never appears in a process listing.

The branch is `<KEY>-<slugified-summary>`, e.g. `SRE-1234-add-a-retry-to-the-upload-queue`.
The key keeps its capitals, which is how Jira spots a branch for a ticket and
links it in the ticket's development panel. Everything else — the
`[worktree]` flag, reopening after a rename, the start prompt — works as for
issues.

The picker lists open tickets of `WT_JIRA_PROJECT`, newest activity first, with
`--mine` narrowing it to yours; without a project it lists only yours, since
every open ticket on a site is no use to pick from. `WT_JIRA_JQL` replaces the
query outright (leave out `ORDER BY`; `--mine` still applies). The preview pane
shows the ticket's status, assignee and description.

Only once `WT_JIRA_URL` is set does a bare `ABC-123` mean a ticket; before
that it is an ordinary branch name. `wt new --jira abc-123` is never ambiguous.

### `wt list` — reopen a worktree

```sh
wt list                 # the picker, on the Worktrees tab
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

**What the tab in each worktree is doing** is marked too, when iTerm2 can say:

```
  1234-add-a-retry-to-the-upload-queue   [PR #1240 open]  [claude waiting for you]
  1189-cache-the-dashboard-summary       [✓ PR #1201 merged]  [tab open]
  1301-retry-the-webhook                 [claude working]
```

`[claude waiting for you]` (magenta) means its `claude` has stopped and wants
an answer; `[claude working]` (blue) is mid-turn; `[tab open]` (grey) means a
tab is there but nothing is running in it that reports its status. When a
worktree has several tabs, the one that most needs you wins. Type `waiting`
into the picker to see only the sessions holding up on you. This comes from
iTerm2 3.7's Session Status, which its Claude Code integration feeds, read in
one `it2 session list` call; with an older iTerm2, the API off, or the
integration not installed, the marks are left out or reduced to `[tab open]`.

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
same way `wt rm` finds them (by the tag `wt` gave the tab, or by where its
processes actually are), and the tab you ran `wt list` from doesn't count. Only when no tab is in the worktree
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
is safe to clear away, a `[PR #1240 open, checks failing]` probably isn't.
`wt rm <branch>` prints the branch's pull request before it removes anything.

The quickest way to clear out finished work is therefore `wt rm`, type
`merged`, then <kbd>Tab</kbd> through what's left and press <kbd>Enter</kbd>.

Selecting is the decision: there is no extra "Proceed?" step, so what you pick
is removed straight away. It then asks per worktree whether to delete the local
branch too. When that's done it drops you back into the picker with what's
left, so you can keep clearing without re-running the command; <kbd>Esc</kbd>
(or a blank answer in the numbered list) is what ends it.

A few safety behaviours, since removal is forced underneath:

- **Uncommitted changes** are flagged in the picker and need a separate
  confirmation before they're discarded. Declining skips that one and continues.
- **Stale entries** — worktrees whose directory you already deleted by hand —
  are flagged `[missing, stale entry]` and deregistered without prompting, since
  there's no work left to lose.
- **The main working tree is never listed**, and the worktree you're currently
  standing in is flagged and skipped rather than failing mid-run.
- **Its iTerm2 tabs are closed with it.** A tab left sitting in a directory
  that no longer exists is stranded — every command it runs fails, and a
  `claude` in it has lost the tree it was working on. A tab `wt` opened is
  tagged with its worktree (an iTerm2 user variable, `user.wt_worktree`) and
  found by that tag. Any other tab is found by asking the kernel where each
  session's processes actually are, not iTerm2's `session.path`, which only
  refreshes when the shell draws a prompt. Tabs are closed only after the
  removal itself succeeds. `WT_KEEP_TABS=1` turns this off.
- **A `claude` still mid-turn** needs a confirmation before its worktree goes,
  since whatever it was doing would be lost. This needs iTerm2 3.7 and its
  Claude Code integration, which report when a `claude` is working; without
  them there's no such prompt.

### `wt status` — everything at once

```sh
wt status               # every worktree in every repo, one line each
wt status --json        # the same, for scripts and the orchestrator
wt status --no-pr       # skip asking GitHub (also WT_NO_PR=1)
```

```
wt/12-retry-uploads        waiting (question)     PR #14 open passing    https://github.com/abaidan/wt/issues/12
wt/15-cache-summary        working                                       https://github.com/abaidan/wt/issues/15
traq/SRE-7068-nats-alerts  idle                   PR #339 open failing   https://example.atlassian.net/browse/SRE-7068
```

Unlike the other commands it isn't tied to the repo you're standing in. It
finds every repo with a worktree under `$WT_ROOT` and lists all of their
worktrees, plus a repo's main checkout when a `claude` that `wt` started has
run there. Each row has its pull request (state and checks), the issue or
ticket it was made for, and what its `claude` is doing, from the
[session state](#session-state) hooks: `idle`, `working`, `waiting` and on what,
`error`, `ended`, or `crashed` when its process is gone mid-turn. Pull requests
are looked up with one GitHub query per repo, not one per worktree.

`--json` also gives each session's last message, its transcript and how long
that has been quiet, and whether a tab is open in it. The tab comes from
iTerm2 when it can say, and is `null` when it can't.

## Configuration

All optional, all environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `WT_ROOT` | `~/worktrees` | Where worktrees are stored, as `$WT_ROOT/<repo>/<branch>`. |
| `WT_BASE_BRANCH` | the repo's default branch | Branch to create new branches from. |
| `WT_CLAUDE_ARGS` | `--permission-mode auto` | Arguments passed to `claude`. Set empty for a plain `claude`. |
| `WT_NO_CLAUDE` | unset | Set to `1` to open the tab and `cd` there without launching Claude. |
| `WT_PROMPT_TEMPLATE` | `Work on this GitHub issue: {url} Open PR, watch bots.` | Prompt typed into Claude in a newly created issue worktree; `{url}` is replaced with the issue URL. Set empty to disable. |
| `WT_PR_PROMPT_TEMPLATE` | `Work on this pull request: {url} Watch bots.` | The same, for a pull request's worktree. |
| `WT_JIRA_PROMPT_TEMPLATE` | `Work on this Jira ticket: {url} Open PR, watch bots.` | The same, for a Jira ticket's worktree. |
| `WT_PREFILL_DELAY` | `6` | Seconds to wait for Claude to start before typing that prompt. |
| `WT_ISSUE_LIMIT` | `1000` | Most open issues, pull requests or tickets a picker fetches; fzf searches all of them. |
| `WT_NO_PULL` | unset | Set to `1` so `wt new` only fetches, leaving your local base branch where it is. |
| `WT_NO_PR` | unset | Set to `1` to skip pull request lookups in the `wt list` / `wt rm` pickers. |
| `NO_COLOR` | unset | Set to anything to turn off colour in the pickers. |
| `WT_KEEP_TABS` | unset | Set to `1` to leave a removed worktree's iTerm2 tabs open. |
| `WT_NO_TAB_TITLE` | unset | Set to `1` to keep `PR #<n>` out of the tab title. |
| `WT_NO_STATE` | unset | Set to `1` to stop recording what each `claude` that `wt` starts is doing (see [Session state](#session-state)). |
| `WT_NEW_TAB` | unset | Set to `1` to always open a new tab when reopening a worktree, even if one is already open in it. |
| `WT_JIRA_URL` | unset | Your Jira Cloud site, e.g. `https://example.atlassian.net`. Turns the Jira support on. |
| `WT_JIRA_EMAIL` | `git config --global user.email` | The Atlassian account to sign in as. |
| `WT_JIRA_TOKEN` | the keychain's `wt-jira` entry | Atlassian API token. |
| `WT_JIRA_PROJECT` | unset | Project the Jira picker lists open tickets of. |
| `WT_JIRA_JQL` | unset | JQL filter replacing the Jira picker's default (no `ORDER BY`). |

### The start prompt

In a **newly created** worktree for an issue, a pull request or a Jira ticket,
its URL is typed into Claude's prompt box and left there — you press enter yourself,
or edit it first, or ignore it. Nothing is submitted on your behalf.

It is typed rather than passed as an argument, via iTerm2's `write … newline no`,
which is why there's a delay: Claude needs a moment to draw its prompt box, and
anything sent before that is dropped. If the prompt lands truncated or not at
all, raise `WT_PREFILL_DELAY`.

Two deliberate limits:

- **Only new worktrees.** Reopening through `wt list`, `wt open`, or a `wt new`
  that finds an existing worktree never prefills — that session has its own
  history and the link would just be in the way.
- **Only worktrees made for an issue, pull request or ticket.** A branch given
  by name gets nothing, even one that happens to start with a number.

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

### Session state

The same settings file also gives each `claude` that `wt` starts hooks that
record what it is doing, under `~/.local/state/wt` (or `$XDG_STATE_HOME/wt`):

- `sessions/<worktree>-<hash>.json` holds each worktree's latest state:
  `idle`, `working`, `waiting` (on a question, a permission or other input),
  `error` or `ended`, plus its last message and transcript path.
- `events.jsonl` gets one line per change of state. It is rotated to
  `events.1.jsonl` at 5 MB.

Nothing goes over the network and nothing in it comes from iTerm2. The hooks
never print or fail, so a problem with them can't show up in a session.
A `claude` started before upgrading `wt` keeps the hooks it started with;
restart it to pick these up. Set `WT_NO_STATE=1` to turn this off.

`wt events` prints those changes as JSON lines, each with a `cursor` to pass
back as `--since`. `wt events --wait` blocks until a session needs looking
at: one waiting on a question or a permission, one that finished a turn with
no background work left, or an error. It then gives a burst two seconds to
land, prints it and exits. `--timeout <s>` gives up after that long with a
`timeout` record; `--all` wakes on every change instead.

## Keeping the Mac awake

Not part of `wt` itself, but useful when several worktrees have agents working
at once: [`contrib/claude-caffeinate.sh`](contrib/claude-caffeinate.sh) is a
Claude Code hook that stops macOS from idle-sleeping while a session is busy.
It works for every `claude`, not only ones `wt` started.

Install it, then add the hooks to `~/.claude/settings.json`. Merge them into
your existing `hooks` arrays; don't replace those arrays:

```sh
mkdir -p ~/.claude/hooks
cp contrib/claude-caffeinate.sh ~/.claude/hooks/caffeinate.sh
```

```json
{
  "hooks": {
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/caffeinate.sh start", "timeout": 5 }] }],
    "SubagentStart":    [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/caffeinate.sh start", "timeout": 5 }] }],
    "PreToolUse":       [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/caffeinate.sh start", "timeout": 5 }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/caffeinate.sh stop",  "timeout": 5 }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/caffeinate.sh stop",  "timeout": 5 }] }]
  }
}
```

How it behaves:

- **Starts** when you submit a prompt, a subagent starts, or any tool runs. The
  tool trigger means background subagents still working after the main turn
  ends keep the Mac awake too.
- **Stops** at the end of each turn and when the session ends.
- One `caffeinate -i -m` per session, so calling `start` again doesn't spawn
  another. It is tied to the `claude` process with `-w`, so it exits with
  Claude Code even after a crash or a missed stop hook.
- **Closing the lid still sleeps the Mac.** `caffeinate` only prevents idle
  sleep. The display can still turn off, which doesn't pause agents; add `-d`
  in the script if you want it kept on.

Check what is holding the Mac awake with `pmset -g assertions | grep caffeinate`.

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

## License

MIT — see [LICENSE](LICENSE).
