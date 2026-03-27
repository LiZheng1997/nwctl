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

### 1. Merge dev into main

```bash
git checkout main
git merge dev
git push origin main
```

### 2. Update version number

Edit `nwctl` file, update `NWCTL_VERSION`:
```bash
# Example: bump from 0.1.0 to 0.2.0
sed -i 's/NWCTL_VERSION="0.1.0"/NWCTL_VERSION="0.2.0"/' nwctl
git add nwctl
git commit -m "chore: bump version to 0.2.0"
git push origin main
```

### 3. Tag and push

```bash
git tag v0.2.0
git push origin main --tags
```

This triggers the GitHub Actions release workflow which:
- Runs CI checks (shellcheck + validation)
- Verifies tag version matches `NWCTL_VERSION`
- Creates a tarball `nwctl-0.2.0.tar.gz`
- Generates changelog from commits
- Creates a GitHub Release with the tarball attached

### 4. Sync to organization repo

```bash
git push org main dev --tags
```

This also triggers the release workflow on the org repo.

## Full Release Checklist

```bash
# 1. Ensure dev is up to date and CI passes
git checkout dev
git push origin dev

# 2. Merge to main
git checkout main
git merge dev

# 3. Bump version
sed -i 's/NWCTL_VERSION="OLD"/NWCTL_VERSION="NEW"/' nwctl
git add nwctl
git commit -m "chore: bump version to X.Y.Z"

# 4. Push main + tag to personal repo
git push origin main
git tag vX.Y.Z
git push origin main --tags

# 5. Sync to org repo
git push org main dev --tags

# 6. Switch back to dev for next cycle
git checkout dev
git merge main
git push origin dev
```

## Hotfix Process

```bash
# Branch from main
git checkout main
git checkout -b hotfix/fix-description

# Fix, commit, merge back
git commit -m "fix: description"
git checkout main
git merge hotfix/fix-description

# Tag and release (follow steps 3-6 above)
```

## Optional: Push to Both Repos at Once

To avoid running `git push` twice, configure dual push URLs:

```bash
git remote set-url --add --push origin git@github.com:LiZheng1997/nwctl.git
git remote set-url --add --push origin git@github.com:uwa-rev/nwctl.git

# Now a single push goes to both repos
git push origin main --tags
```
