# AGENTS

This project uses a worktree-first workflow for feature development.

## Branching

- Create new feature branches as separate git worktrees off `main`.
- After creating a new feature branch, set its Graphite parent to `main`:

```bash
gt track -p main
```

- For very complex features, or for features that benefit from stacked branch paths, create additional worktree branches off the active feature branch and track them to that parent branch.
- Create stacked child branches only when the child work directly depends on changes in the parent branch.
- If new work is tangential, independent, or can be delivered without the parent branch, create a separate worktree branch from `main` instead.
- Do not stack unrelated work on a feature branch just because it was discovered while working there.
- Prefer aggressively splitting unrelated work into separate worktrees instead of mixing multiple features into one branch.

## Commit shape

- Each worktree branch should ideally be squashed down to a single logical commit.
- If a branch needs multiple commits during development, keep them tightly related and collapse them before merge when practical.

## Keeping branches current

- Before continuing work on an existing worktree branch, restack it:

```bash
gt restack
```

- Treat `gt restack` as the default way to bring a branch up to date with its parent before additional changes.

## Validation

- A feature must pass:

```bash
make test
```

- Do not merge feature work back into `main` until tests pass.

## Merging

- Merge back into `main` with fast-forward only:

```bash
git merge --ff-only <branch>
```

- Do not create merge commits when landing feature branches into `main`.

## Cleanup

- After a worktree branch has been merged into `main`, remove the worktree and delete the underlying branch.
- Keep the repo tidy by removing merged worktrees promptly.
