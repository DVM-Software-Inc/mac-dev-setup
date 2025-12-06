# 🚀 DVM Projects GitHub Sync Guide

## Overview

You now have 4 active projects synced to GitHub under the `DVM-Software-Inc` organization:

1. **dvm-fullstack** - Full-stack project (Node.js frontend + Python backend)
2. **smb-tax** - SMB Tax project (Go)
3. **md-reader** - MD Reader project (Node.js)
4. **mermaid-thing** - Mermaid Thing project

All projects are on GitHub and ready for multi-machine development.

## Quick Start: New Machine Setup (M4 Laptop)

### Step 1: Copy the sync script

```bash
# Copy dvm-sync.sh to your new machine
scp your_username@old_mac:~/code/dvm-sync.sh ~/code/dvm-sync.sh
# or use AirDrop/external drive
```

### Step 2: Set up Git configuration

```bash
cd ~/code
./dvm-sync.sh setup
```

This will configure:
- Git user: `DVM-Software`
- Git email: `DVM-Software@users.noreply.github.com`
- Default branch: `main`

### Step 3: SSH Key Setup

Generate SSH key for GitHub (if not already done):

```bash
ssh-keygen -t ed25519 -C "DVM-Software@users.noreply.github.com" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add public key to GitHub:
```bash
cat ~/.ssh/id_ed25519.pub
# Copy output → https://github.com/settings/keys → New SSH key
```

Verify connection:
```bash
ssh -T git@github.com
```

### Step 4: Clone all projects

```bash
cd ~/code
./dvm-sync.sh clone
```

This will clone all 4 projects into `~/code/`:
- `~/code/dvm-fullstack`
- `~/code/smb-tax`
- `~/code/md-reader`
- `~/code/mermaid-thing`

## Daily Workflow

### Pull latest changes from all projects

Before starting work:
```bash
./dvm-sync.sh pull
```

### After making changes

When you've finished working and want to sync:

```bash
./dvm-sync.sh push
```

This will:
1. Detect changes in each repo
2. Auto-commit with timestamp
3. Push to GitHub

**Or manually if you prefer:**
```bash
cd ~/code/specific-project
git add .
git commit -m "Your commit message"
git push origin main
```

### Check status of all projects

```bash
./dvm-sync.sh status
```

## GitHub Repositories

- https://github.com/DVM-Software-Inc/dvm-fullstack
- https://github.com/DVM-Software-Inc/smb-tax
- https://github.com/DVM-Software-Inc/md-reader
- https://github.com/DVM-Software-Inc/mermaid-thing

## Current Machine: Sync from Here

You're already set up on this machine. To sync to your M4 laptop:

```bash
# Make sure all changes are pushed
./dvm-sync.sh push

# Then on the M4 machine, clone all projects
./dvm-sync.sh clone
```

## Available Commands

```bash
./dvm-sync.sh clone    # Clone all repos (first time only)
./dvm-sync.sh pull     # Pull latest from all repos
./dvm-sync.sh push     # Push changes from all repos
./dvm-sync.sh status   # Show git status for all repos
./dvm-sync.sh setup    # Configure git credentials
./dvm-sync.sh help     # Show help
```

## Troubleshooting

### SSH Connection Issues

If you get permission denied errors:

```bash
# Verify SSH key is added
ssh-add -l

# If not, add it:
ssh-add ~/.ssh/id_ed25519

# Test connection
ssh -T git@github.com
```

### Already have local repos?

If you already have some projects locally and want to sync:

```bash
cd ~/code/your-project
git remote add origin git@github.com:DVM-Software-Inc/repo-name.git
git branch -M main
git push -u origin main
```

### Need to switch machines?

1. On current machine: `./dvm-sync.sh push`
2. On new machine: `./dvm-sync.sh clone`
3. Copy any uncommitted work manually if needed

## Best Practices

✅ **DO:**
- Pull before starting work: `./dvm-sync.sh pull`
- Push after making changes: `./dvm-sync.sh push`
- Use meaningful commit messages
- Keep repos in sync between machines

❌ **DON'T:**
- Work on the same project on two machines without syncing
- Ignore merge conflicts
- Force push unless you know what you're doing

## Advanced: Manual Git Operations

For more control, use git directly:

```bash
cd ~/code/project-name

# Status
git status

# View changes
git diff

# Commit specific changes
git add path/to/files
git commit -m "Descriptive message"

# Push to GitHub
git push origin main

# Pull updates
git pull origin main

# View commit history
git log --oneline
```

## Need Help?

- GitHub CLI docs: https://cli.github.com/manual
- Git docs: https://git-scm.com/doc
- SSH setup: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
