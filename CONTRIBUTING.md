# nwctl Development & Release Guide

## Repository Setup

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `git@github.com:LiZheng1997/nwctl.git` | Personal repo (primary development) |
| `org` | `git@github.com:uwa-rev/nwctl.git` | Organization repo (team distribution) |

## Branch Strategy

```
dev     Development branch (daily work)
main    Stable branch (releases only)
```

> Note: `develop` branch is deprecated. Use `dev` only.

## Daily Development

```bash
# Work on dev branch
git checkout dev

# Make changes, commit
git add -A
git commit -m "feat/fix/chore: description"

# Push to personal repo
git push origin dev
```

## Release Process

### 1. Sync with remote before starting

Always fetch and rebase before merging/pushing to avoid conflicts:

```bash
git fetch origin
git fetch org
```

### 2. Merge dev into main

```bash
git checkout main
git rebase origin/main    # Ensure local main is up to date
git merge dev
```

### 3. Update version number

Edit `nwctl` file, update `NWCTL_VERSION`:
```bash
# Example: bump from 0.1.1 to 0.2.0
sed -i 's/NWCTL_VERSION="0.1.1"/NWCTL_VERSION="0.2.0"/' nwctl
git add nwctl
git commit -m "chore: bump version to 0.2.0"
```

### 4. Push to personal repo first

```bash
git push origin main
```

### 5. Tag

```bash
git tag v0.2.0
git push origin v0.2.0
```

This triggers the GitHub Actions release workflow which:
- Runs CI checks (shellcheck + validation)
- Verifies tag version matches `NWCTL_VERSION`
- Creates a tarball `nwctl-0.2.0.tar.gz`
- Generates changelog from commits
- Creates a GitHub Release with the tarball attached

### 6. Sync to organization repo

Always push **after** personal repo succeeds:

```bash
git push org main --tags
```

### 7. Sync dev branch

```bash
git checkout dev
git merge main
git push origin dev
git push org dev
```

## Full Release Checklist

```bash
# 1. Ensure dev is up to date and CI passes
git checkout dev
git push origin dev

# 2. Sync local main with remote
git checkout main
git fetch origin
git rebase origin/main

# 3. Merge dev into main
git merge dev

# 4. Bump version
sed -i 's/NWCTL_VERSION="OLD"/NWCTL_VERSION="NEW"/' nwctl
git add nwctl
git commit -m "chore: bump version to X.Y.Z"

# 5. Push main to personal repo FIRST
git push origin main

# 6. Tag and push tag
git tag vX.Y.Z
git push origin vX.Y.Z

# 7. Sync to org repo
git push org main --tags

# 8. Switch back to dev for next cycle
git checkout dev
git merge main
git push origin dev
git push org dev
```

## Hotfix Process

```bash
# Branch from main
git checkout main
git fetch origin && git rebase origin/main
git checkout -b hotfix/fix-description

# Fix and commit
git add -A
git commit -m "fix: description"

# Merge back to main
git checkout main
git merge hotfix/fix-description

# Delete hotfix branch
git branch -d hotfix/fix-description

# Follow release steps 4-8 above
```

## Troubleshooting

### Push rejected (non-fast-forward)

This means the remote has commits you don't have locally. Fix with:

```bash
git fetch origin
git rebase origin/main
# Then push again
git push origin main
```

### Tag already exists on remote

```bash
# Delete remote tag, re-create and push
git push origin --delete vX.Y.Z
git tag -d vX.Y.Z
git tag vX.Y.Z
git push origin vX.Y.Z
```

## Optional: Push to Both Repos at Once

To avoid running `git push` twice, configure dual push URLs:

```bash
git remote set-url --add --push origin git@github.com:LiZheng1997/nwctl.git
git remote set-url --add --push origin git@github.com:uwa-rev/nwctl.git

# Now a single push goes to both repos
git push origin main --tags
```
