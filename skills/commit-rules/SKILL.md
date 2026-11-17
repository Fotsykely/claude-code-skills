---
name: commit-rules
description: Commit changes safely and cleanly in any git repository. Checks the current branch first (never commits on main/default/protected branches; creates a type/short-name branch when needed), reads recent commit history to match the repo's style, writes the message in English following Conventional Commits, stages explicit paths, makes small logical commits, and never pushes. Use this whenever the user says commit, "commit ça", save my work to git, or asks to commit in any form, even if they do not name the skill.
argument-hint: "[optional: what to commit, or a branch name]"
---

# commit-rules

Commit the current changes following these steps in order. The branch check comes first, every time.

## 1. Check the branch (never skip)

The branch can change between two requests (a PR got merged, the user switched). Do not trust earlier context:

```bash
git branch --show-current
git status --short
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null   # default branch; else main or master
```

**Never commit on the default branch or a long-lived one** (`main`, `master`, `develop`, `preprod`, `staging`, `production`, `release/*`). Why: those branches are what gets deployed and reviewed through PRs; a stray commit there is awkward to undo once pushed.

- On such a branch: create `<type>/<short-kebab-name>` (`type` = the commit type, e.g. `fix/cart-total`) with `git switch -c <name> --no-track`, then commit there. `--no-track` stops a bare `git push` from targeting the base branch.
- On a feature branch: commit there only if the work is **related** and the branch is **not already merged** (its PR merged, listed by `git branch --merged <default>`, or its remote is gone). Otherwise branch off the up-to-date default branch (`git fetch` is fine; no pull or merge unprompted). If unsure whether the work belongs, ask.
- A commit already landed on a protected branch and was **not pushed**: `git switch -c <branch> --no-track`, then `git branch -f <default> origin/<default>`. Nothing is lost. If it **was pushed**, stop and ask.

Say which branch you commit on, and that you created it if you did.

## 2. Read what you commit

`git diff` and `git diff --staged`. Describe what the diff actually does. Leave out secrets and local files (`.env*`, keys, tokens, `settings.local.json`, build output): unstage them and tell the user.

## 3. Learn the repo's conventions

Repo rules win over the defaults here. Read `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` or a commit template if present, then match the real style:

```bash
git log --no-merges -20 --format='%s'
git log --no-merges -3 --format='%B---'
```

Take the types, scopes, structure and body habits from it. The language is the exception: always English.

## 4. Write the message (always English)

```
<type>(<scope>): <subject>

<body: why and effect, not a recap of the diff>
```

- **Always English**, subject and body, merge commits and PR text included. A quoted UI string in another language stays quoted inside an English sentence.
- Conventional Commits: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`, lowercase. Scope from the scopes already in the history, or none.
- Subject: imperative ("add", not "added"), no final period, 72 characters or fewer.
- Body (when the subject is not enough): what a reviewer must know (behaviour change, snapshot changed on purpose, env var, something to deploy elsewhere). Breaking change: `type!:` plus a `BREAKING CHANGE:` paragraph.
- End with the attribution line the session's system reminder asks for, if any; invent none. `Fixes #123` only when the user gives an issue.

Commit with a heredoc: `git commit -F - <<'EOF' … EOF`.

## 5. Small logical commits

One concern per commit, each one building and passing on its own; never one giant commit. Separate refactors and mechanical moves from behaviour changes; keep a change's tests and docs with it. Stage **explicit paths** (`git add a b`), never `git add -A` or `.`, then check `git diff --staged --stat`. When several commits are needed, list them in one line first.

## 6. Check before committing

Run what the repo uses on what changed (types, linter, tests; commands are in `CLAUDE.md`, `package.json` or `Makefile`) and say what you skipped. Do not hide a failure; say if it predates your change.

## 7. After

`git log --oneline -n <commits made>` and `git status --short`. Report the branch, each hash and subject, and the checks run.

**If you created a branch during this run, finish with the pull request URL** (see "Pull request URLs" below), even though nothing is pushed yet: the user can open it once they push.

## Never, unless the user asks

`git push` (any form), `--force`, `--amend`, `--no-verify`, opening or merging a PR. If a hook fails, fix the cause and make a new commit. End by offering to push; when asked, use `git push -u origin <branch>` with an explicit target.

## Pull request URLs

At the end of a commit run **that created a branch**, and at the end of every **push** of a branch, print the URL to open the pull request. Build it from the `origin` remote, never invent it:

```bash
git remote get-url origin   # git@github.com:owner/repo.git or https://github.com/owner/repo.git
```

Normalize to `https://github.com/<owner>/<repo>` (drop `.git`, convert the SSH form), then print one URL per branch involved:

```
https://github.com/<owner>/<repo>/compare/<base>...<branch>?expand=1
```

- `<base>` is the default branch (step 1); `<branch>` is the branch committed or pushed.
- Several branches created or pushed in the same run: one line per branch, `<branch> → <url>`.
- After a push, if `git push` printed a `Create a pull request ... remote:` URL, prefer that one.
- Non-GitHub remote (GitLab, Bitbucket…): use that host's equivalent compare/merge-request URL, or say the host is unknown and skip it.
- Only print the URL. Do not open the PR (`gh pr create`) unless the user asks.
