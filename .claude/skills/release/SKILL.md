---
name: release
description: Cut a new release of wt - pick the version bump, tag it with ./release, push the tag, reinstall ~/bin/wt, and publish a GitHub release with written notes. Use when asked to "tag a release", "cut a release", "release wt", "ship a new version", or to create a GitHub release for a tag.
---

# Releasing wt

A release is three things, in this order: an annotated git tag on `main` (made by
`./release`), the reinstalled local copy (so `wt --version` reports the tag), and
a GitHub release whose notes a reader can skim.

Arguments, if given, are a bump (`patch` / `minor` / `major`) or an exact
version (`1.2.3`). Without one, choose the bump yourself (step 2).

## 1. Check the starting point

```sh
git status --short                 # must be empty
git fetch --quiet origin --tags
git status -sb | head -1           # main must be level with origin/main
git describe --tags --abbrev=0     # the previous release
git log --oneline "$(git describe --tags --abbrev=0)"..HEAD
```

- Uncommitted changes: stop and ask whether to commit them first. Don't stash
  or discard them.
- `main` is ahead of origin: the commits must be pushed before tagging, since a
  tag on an unpushed commit points at nothing for everyone else. Ask before
  pushing, unless the user already asked for the push.
- No commits since the last tag: there is nothing to release, so say so and stop.

`./release` enforces all of these too and runs `./build --check`, but checking
first means you can explain a problem rather than relay its error.

## 2. Pick the version

Read the commits since the last tag, not just their subjects if any are unclear.

- **patch**: fixes and behaviour tweaks that need nothing from the user
- **minor**: a new subcommand, flag or env var, or a changed default the user
  will notice
- **major**: something that breaks existing usage, such as a removed or renamed
  command, flag or env var, or a changed branch or worktree layout

Say which bump you chose and why, in one line. If it falls between two levels,
pick the lower one and say so. While on v0.x, breaking changes go in a minor
bump unless the user asks for 1.0.

## 3. Tag and push

```sh
./release <bump> --dry-run    # shows the version and the commit list
./release <bump> --push
```

The tag message is the raw commit list. That is fine for the tag, and the
GitHub notes are written separately.

## 4. Reinstall locally

```sh
./build && wt --version       # should print exactly the new tag, e.g. wt v0.1.2
```

If the version has a `-dirty` or `-N-g<sha>` suffix, the tag isn't on the
checked-out commit, or the tree isn't clean. Fix that before going on.

## 5. Publish the GitHub release

```sh
gh release view <tag> >/dev/null 2>&1 && echo exists   # never create it twice
```

Write the notes to a file in the scratchpad, not in the repo:

```markdown
## What's changed

- **<User-facing change, as a short bolded sentence.>** One or two plain
  sentences on what it means in practice: new defaults, env vars, flags.
- ...

**Full changelog:** https://github.com/<owner>/<repo>/compare/<prev>...<tag>
```

- One bullet per change a user would notice, most significant first. Combine
  related commits, and leave out internal-only ones such as refactors, README
  typos and build tweaks, unless nothing else changed.
- Describe behaviour, not the commit subject, e.g. "searches all open issues"
  rather than "Raise WT_ISSUE_LIMIT".
- Call out anything breaking, or any step the user must take, at the very top
  under a `### Breaking` heading.
- Get `<owner>/<repo>` from `gh repo view --json nameWithOwner -q .nameWithOwner`.

```sh
gh release create <tag> --verify-tag --title "wt <tag>" --notes-file <file>
```

`--verify-tag` makes it fail rather than create a new tag if the push in step 3
didn't land. To fix the notes later, use `gh release edit <tag> --notes-file
<file>` and don't recreate the release.

## 6. Report

Give the tag, the commit it's on, the bump and why, the `wt --version` output,
and the release URL.
