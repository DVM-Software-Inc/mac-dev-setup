#!/bin/bash

#############################################################################
# DVM Projects Sync Script
# Syncs all DVM-Software-Inc projects between machines via GitHub
#
# Usage:
#   ./dvm-sync.sh clone    # Clone all repos (initial setup on new machine)
#   ./dvm-sync.sh pull     # Pull latest from all repos
#   ./dvm-sync.sh push     # Push changes from all repos
#   ./dvm-sync.sh status   # Show git status for all repos
#############################################################################

set -e

# Configuration
ORG="DVM-Software-Inc"
BASE_DIR="$HOME/code"
# GIT_PROTOCOL: "ssh" or "https" — auto-detected if not set via env
# Override: GIT_PROTOCOL=https ./dvm-sync.sh clone
GIT_PROTOCOL="${GIT_PROTOCOL:-auto}"

# Branch manifest — records each repo's working branch so the other machine
# lands on the right branch after a clone. Lives in mac-dev-setup (synced first).
BRANCH_MANIFEST="$BASE_DIR/mac-dev-setup/dvm-sync-branches.tsv"

# This script lives in mac-dev-setup — it syncs itself along with everything else
REPOS=(
  "mac-dev-setup"
  "buktub"
  "cc_dvm"
  "chatactorai"
  "comfyui_cloud"
  "ConfyUI-dvm"
  "contextorai"
  "deeployai"
  "dev-tools"
  "dvm-fullstack"
  "extractor-statements"
  "factory_docs_gen"
  "factory_repo"
  "health"
  "infra"
  "knowingbest"
  "maestorai"
  "makeroo"
  "md-player"
  "md-reader"
  "mermaid-thing"
  "pro-cure-ai"
  "qe_automaton"
  "setup"
  "smb-tax"
  "stock-analyst"
  "tattoo-on-me"
  "telegram"
  "todo"
  "vault"
  "vps_deploy"
  "web_templates"
  "yt-slopper"
)

# Repos under a different org (clone URL override)
# Add cases here for repos not under the default ORG

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#############################################################################
# Functions
#############################################################################

print_header() {
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

check_prerequisites() {
  if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install git first."
    exit 1
  fi

  if ! command -v gh &> /dev/null; then
    print_info "GitHub CLI not found. Install it for HTTPS auth or configure SSH keys."
  fi

  if [ ! -d "$BASE_DIR" ]; then
    print_info "Creating $BASE_DIR..."
    mkdir -p "$BASE_DIR"
  fi

  detect_protocol

  # Set up gh as git credential helper for HTTPS if available
  if [ "$GIT_PROTOCOL" = "https" ] && command -v gh &>/dev/null; then
    if ! git config --global credential.https://github.com.helper 2>/dev/null | grep -q "gh auth"; then
      print_info "Setting up gh as git credential helper for HTTPS..."
      gh auth setup-git
    fi
  fi
}

get_repo_org() {
  local repo="$1"
  case "$repo" in
    cc_dvm) echo "DVM-Software" ;;
    *)      echo "$ORG" ;;
  esac
}

# Maps a local directory name to its GitHub repo name when they differ.
# (e.g. the vps_deploy/ folder is the vps-deploy repo on GitHub)
get_repo_remote_name() {
  local repo="$1"
  case "$repo" in
    vps_deploy) echo "vps-deploy" ;;
    *)          echo "$repo" ;;
  esac
}

detect_protocol() {
  if [ "$GIT_PROTOCOL" != "auto" ]; then
    return
  fi
  # Prefer SSH if keys exist and can connect
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    GIT_PROTOCOL="ssh"
  elif command -v gh &>/dev/null && gh auth status &>/dev/null; then
    # gh is authed — use HTTPS with gh credential helper
    GIT_PROTOCOL="https"
  else
    # Fallback: check for SSH key files
    if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
      GIT_PROTOCOL="ssh"
    else
      GIT_PROTOCOL="https"
    fi
  fi
  print_info "Using $GIT_PROTOCOL protocol (override with GIT_PROTOCOL=ssh|https)"
}

get_clone_url() {
  local repo_org="$1"
  local repo="$2"
  if [ "$GIT_PROTOCOL" = "ssh" ]; then
    echo "git@github.com:$repo_org/$repo.git"
  else
    echo "https://github.com/$repo_org/$repo.git"
  fi
}

clone_repos() {
  print_header "🔄 Cloning all repos from $ORG"

  cd "$BASE_DIR"

  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    local repo_org
    repo_org=$(get_repo_org "$repo")
    local remote_name
    remote_name=$(get_repo_remote_name "$repo")

    if [ -d "$local_path/.git" ]; then
      print_info "$repo already exists (skipping clone)"
      continue
    fi

    if [ -d "$local_path" ] && [ ! -d "$local_path/.git" ]; then
      # Directory exists but isn't a git repo — init and create remote
      print_info "$repo exists locally but has no git repo, initializing..."
      cd "$local_path"
      git init
      git add .
      git commit -m "Initial commit via dvm-sync"
      if command -v gh &> /dev/null; then
        gh repo create "$repo_org/$remote_name" --private --source=. --push
        print_success "$repo initialized and pushed to $repo_org/$remote_name"
      else
        print_error "$repo initialized locally but gh CLI needed to create remote"
      fi
      cd "$BASE_DIR"
      continue
    fi

    echo ""
    echo "📦 Cloning $repo..."
    local clone_url
    clone_url=$(get_clone_url "$repo_org" "$remote_name")
    git clone "$clone_url" "$repo"
    print_success "$repo cloned"
  done

  echo ""
  print_success "All repos cloned!"

  # Land each repo on its recorded working branch
  restore_branches
}

pull_repos() {
  print_header "⬇️  Pulling latest from all repos"

  local total=0
  local updated=0
  local skipped=0

  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"

    if [ ! -d "$local_path/.git" ]; then
      print_error "$repo not found at $local_path (run 'clone' first)"
      continue
    fi

    cd "$local_path"

    # Skip repos with no remote
    if ! git remote get-url origin &>/dev/null; then
      print_info "$repo has no remote (skipping)"
      skipped=$((skipped + 1))
      continue
    fi

    # Skip if no upstream tracking branch
    if ! git rev-parse --abbrev-ref @{u} &>/dev/null; then
      print_info "$repo has no upstream tracking branch (skipping)"
      skipped=$((skipped + 1))
      continue
    fi

    total=$((total + 1))
    echo ""
    echo "📦 Pulling $repo..."

    if git pull --rebase --autostash; then
      print_success "$repo pulled (rebased)"
      updated=$((updated + 1))
    else
      print_error "Failed to pull $repo (resolve rebase conflicts manually)"
    fi
  done

  echo ""
  print_success "Pulled $updated/$total repos ($skipped skipped — no remote/upstream)"
}

push_repos() {
  print_header "⬆️  Pushing changes from all repos"

  # Record current branches so the other machine can restore them after clone.
  # Written into mac-dev-setup, which is committed/pushed just below.
  snapshot_branches

  # Sync mac-dev-setup (this script) first so other machines get the latest REPOS list
  local self_repo="mac-dev-setup"
  local self_path="$BASE_DIR/$self_repo"
  if [ -d "$self_path/.git" ]; then
    cd "$self_path"
    if [ -n "$(git status --porcelain)" ]; then
      print_info "Syncing $self_repo first (contains this script)..."
      git add .
      git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
      git push && print_success "$self_repo pushed (script updated for downstream)" \
                || print_error "Failed to push $self_repo"
    fi
  fi

  local total=0
  local pushed=0

  for repo in "${REPOS[@]}"; do
    # mac-dev-setup already pushed above
    [[ "$repo" == "mac-dev-setup" ]] && continue

    local_path="$BASE_DIR/$repo"
    local repo_org
    repo_org=$(get_repo_org "$repo")
    local remote_name
    remote_name=$(get_repo_remote_name "$repo")

    if [ ! -d "$local_path/.git" ]; then
      print_error "$repo not found at $local_path (not a git repo — run 'clone' first)"
      continue
    fi

    total=$((total + 1))
    echo ""
    echo "📦 Checking $repo..."

    cd "$local_path"

    local branch
    branch=$(git branch --show-current 2>/dev/null)

    # Stage and commit if there are any changes (staged, unstaged, or untracked)
    if [ -n "$(git status --porcelain)" ]; then
      print_info "Found changes in $repo, committing..."
      git add .
      git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
    fi

    # Ensure remote exists
    if ! git remote get-url origin &>/dev/null; then
      if command -v gh &> /dev/null; then
        print_info "No remote for $repo, creating GitHub repo..."
        gh repo create "$repo_org/$remote_name" --private --source=. --push
        print_success "$repo created and pushed to $repo_org/$remote_name"
        pushed=$((pushed + 1))
        continue
      else
        print_error "$repo has no remote and gh CLI is not available"
        continue
      fi
    fi

    # Check if there's anything to push (dirty commit above, or previously unpushed commits)
    local ahead=0
    if git rev-parse --abbrev-ref @{u} &>/dev/null; then
      ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    else
      # No upstream — need to push and set upstream
      ahead=1
    fi

    if [ "$ahead" -eq 0 ]; then
      print_info "$repo is up to date"
      continue
    fi

    # Push changes, setting upstream if needed
    if git push -u origin "$branch"; then
      print_success "$repo pushed ($ahead commits on $branch)"
      pushed=$((pushed + 1))
    else
      print_error "Failed to push $repo"
    fi
  done

  echo ""
  print_success "Pushed $pushed/$total repos"
}

snapshot_branches() {
  # Write "<repo>\t<branch>" for every cloned repo to the manifest.
  : > "$BRANCH_MANIFEST"
  local count=0
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    [ -d "$local_path/.git" ] || continue
    cd "$local_path"
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -z "$branch" ] && continue   # skip detached HEAD
    printf '%s\t%s\n' "$repo" "$branch" >> "$BRANCH_MANIFEST"
    count=$((count + 1))
  done
  print_info "Recorded working branches for $count repos → ${BRANCH_MANIFEST#$BASE_DIR/}"
}

restore_branches() {
  if [ ! -f "$BRANCH_MANIFEST" ]; then
    print_info "No branch manifest yet (run 'push' on the source machine first)"
    return
  fi

  print_header "🌿 Restoring working branches"
  local switched=0
  while IFS=$'\t' read -r repo branch; do
    [ -z "$repo" ] && continue
    [ -z "$branch" ] && continue
    local_path="$BASE_DIR/$repo"
    [ -d "$local_path/.git" ] || continue
    cd "$local_path"

    local current
    current=$(git branch --show-current 2>/dev/null)
    if [ "$current" = "$branch" ]; then
      continue   # already on the right branch
    fi

    git fetch origin "$branch" &>/dev/null || true
    if git rev-parse --verify --quiet "$branch" >/dev/null; then
      git checkout "$branch" &>/dev/null && print_success "$repo → $branch"
      switched=$((switched + 1))
    elif git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
      git checkout -b "$branch" --track "origin/$branch" &>/dev/null && print_success "$repo → $branch (new tracking branch)"
      switched=$((switched + 1))
    else
      print_info "$repo: branch '$branch' not found on remote, staying on '$current'"
    fi
  done < "$BRANCH_MANIFEST"

  if [ "$switched" -eq 0 ]; then
    print_info "All repos already on their recorded branches"
  else
    print_success "Switched $switched repos to their recorded branches"
  fi
}

status_repos() {
  print_header "📊 Git status for all repos"

  local synced=0
  local needs_push=0
  local needs_remote=0
  local no_git=0
  local dirty_list=()

  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"

    if [ ! -d "$local_path" ]; then
      echo -e "  ${RED}✗${NC} $repo — ${RED}directory missing${NC} (run 'clone')"
      no_git=$((no_git + 1))
      continue
    fi

    if [ ! -d "$local_path/.git" ]; then
      echo -e "  ${RED}✗${NC} $repo — ${YELLOW}no git repo${NC}"
      no_git=$((no_git + 1))
      continue
    fi

    cd "$local_path"

    local branch
    branch=$(git branch --show-current 2>/dev/null)
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    local changes
    changes=$(git status --porcelain 2>/dev/null | head -5)
    local dirty=""
    [ -n "$changes" ] && dirty=" ${YELLOW}[dirty]${NC}"

    local ahead_behind=""
    if [ -n "$remote_url" ]; then
      local ahead
      ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "")
      local behind
      behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "")
      if [ -n "$ahead" ] && [ "$ahead" -gt 0 ]; then
        ahead_behind=" ${YELLOW}↑${ahead}${NC}"
        needs_push=$((needs_push + 1))
      fi
      if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        ahead_behind="${ahead_behind} ${BLUE}↓${behind}${NC}"
      fi
      if [ -z "$ahead_behind" ] && [ -z "$dirty" ]; then
        echo -e "  ${GREEN}✓${NC} $repo ($branch)${dirty}${ahead_behind}"
        synced=$((synced + 1))
      else
        echo -e "  ${YELLOW}•${NC} $repo ($branch)${dirty}${ahead_behind}"
        [ -n "$dirty" ] && dirty_list+=("$repo")
      fi
    else
      echo -e "  ${RED}!${NC} $repo ($branch)${dirty} — ${RED}no remote${NC}"
      needs_remote=$((needs_remote + 1))
    fi
  done

  echo ""
  print_header "Summary"
  echo -e "  ${GREEN}Synced:${NC}       $synced"
  echo -e "  ${YELLOW}Needs push:${NC}  $needs_push"
  echo -e "  ${RED}No remote:${NC}   $needs_remote"
  echo -e "  ${RED}No git:${NC}      $no_git"
  if [ ${#dirty_list[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}Dirty repos:${NC} ${dirty_list[*]}"
  fi
}

switch_protocol() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    print_error "Usage: ./dvm-sync.sh switch-protocol <ssh|https>"
    exit 1
  fi

  print_header "🔀 Switching all remotes to $target"

  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    if [ ! -d "$local_path/.git" ]; then
      continue
    fi

    cd "$local_path"
    local current_url
    current_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$current_url" ]; then
      continue
    fi

    # Extract org/repo from either format
    local slug=""
    case "$current_url" in
      git@github.com:*) slug="${current_url#git@github.com:}" ; slug="${slug%.git}" ;;
      https://github.com/*) slug="${current_url#https://github.com/}" ; slug="${slug%.git}" ;;
    esac

    if [ -z "$slug" ]; then
      print_info "$repo — unrecognized remote URL, skipping"
      continue
    fi

    local new_url
    if [ "$target" = "ssh" ]; then
      new_url="git@github.com:$slug.git"
    else
      new_url="https://github.com/$slug.git"
    fi

    if [ "$current_url" = "$new_url" ]; then
      print_info "$repo already using $target"
    else
      git remote set-url origin "$new_url"
      print_success "$repo → $new_url"
    fi
  done
}

env_export() {
  local archive="$BASE_DIR/dvm-env-bundle.tar.gz.enc"
  local tmpdir
  tmpdir=$(mktemp -d)

  print_header "📦 Exporting .env files from all repos"

  local count=0
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    if [ ! -d "$local_path" ]; then
      continue
    fi

    # Find all .env* files (skip .env.example, .env.*.example, .git)
    while IFS= read -r envfile; do
      # Skip example/template files
      case "$envfile" in
        *.example) continue ;;
        *.sample)  continue ;;
        *.template) continue ;;
      esac
      # Compute relative path from BASE_DIR
      local relpath="${envfile#$BASE_DIR/}"
      mkdir -p "$tmpdir/$(dirname "$relpath")"
      cp "$envfile" "$tmpdir/$relpath"
      count=$((count + 1))
    done < <(find "$local_path" -maxdepth 3 -name ".env*" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.venv/*" 2>/dev/null)
  done

  if [ "$count" -eq 0 ]; then
    print_info "No .env files found"
    rm -rf "$tmpdir"
    return
  fi

  print_info "Found $count .env files, creating encrypted archive..."

  # Create tar, then encrypt with openssl
  if [ -n "${ENV_PASS:-}" ]; then
    tar -czf - -C "$tmpdir" . | openssl enc -aes-256-cbc -salt -pbkdf2 -pass env:ENV_PASS -out "$archive"
  else
    tar -czf - -C "$tmpdir" . | openssl enc -aes-256-cbc -salt -pbkdf2 -out "$archive"
  fi
  rm -rf "$tmpdir"

  print_success "Encrypted archive: $archive"
  print_info "Transfer to the other machine and run: ./dvm-sync.sh env-import"
}

env_import() {
  local archive="$BASE_DIR/dvm-env-bundle.tar.gz.enc"

  if [ ! -f "$archive" ]; then
    print_error "No env bundle found at $archive"
    print_info "Transfer the file from the source machine first"
    exit 1
  fi

  print_header "📥 Importing .env files from encrypted archive"

  local tmpdir
  tmpdir=$(mktemp -d)

  # Decrypt and extract (prompts for password)
  local pass_flag=""
  if [ -n "${ENV_PASS:-}" ]; then
    pass_flag="-pass env:ENV_PASS"
  fi
  if ! openssl enc -aes-256-cbc -d -salt -pbkdf2 $pass_flag -in "$archive" | tar -xzf - -C "$tmpdir"; then
    print_error "Decryption failed (wrong password?)"
    rm -rf "$tmpdir"
    exit 1
  fi

  local count=0
  local skipped=0
  while IFS= read -r envfile; do
    local relpath="${envfile#$tmpdir/}"
    local target="$BASE_DIR/$relpath"
    local target_dir
    target_dir=$(dirname "$target")

    if [ ! -d "$target_dir" ]; then
      print_info "Skipping $relpath (repo not cloned)"
      skipped=$((skipped + 1))
      continue
    fi

    if [ -f "$target" ]; then
      print_info "Overwriting $relpath"
    fi

    cp "$envfile" "$target"
    count=$((count + 1))
  done < <(find "$tmpdir" -type f 2>/dev/null)

  rm -rf "$tmpdir"

  print_success "Imported $count .env files ($skipped skipped)"
  print_info "You can now delete the bundle: rm $archive"
}

setup_git_config() {
  print_header "🔧 Setting up Git configuration"
  
  # Check if config is already set
  if git config --global user.name | grep -q "DVM-Software"; then
    print_success "Git already configured for DVM-Software"
    return
  fi
  
  echo ""
  print_info "Configuring git user..."
  git config --global user.name "DVM-Software"
  git config --global user.email "DVM-Software@users.noreply.github.com"
  git config --global init.defaultBranch main
  print_success "Git configured"
}

#############################################################################
# Main
#############################################################################

main() {
  local command="${1:-help}"
  
  case "$command" in
    clone)
      check_prerequisites
      setup_git_config
      clone_repos
      ;;
    pull)
      check_prerequisites
      pull_repos
      ;;
    push)
      check_prerequisites
      push_repos
      ;;
    status)
      check_prerequisites
      status_repos
      ;;
    snapshot)
      check_prerequisites
      snapshot_branches
      ;;
    checkout)
      check_prerequisites
      restore_branches
      ;;
    switch-protocol)
      check_prerequisites
      switch_protocol "$2"
      ;;
    env-export)
      env_export
      ;;
    env-import)
      env_import
      ;;
    setup)
      check_prerequisites
      setup_git_config
      ;;
    help|*)
      cat << EOF
${BLUE}DVM Projects Sync Script${NC}

${GREEN}Usage:${NC}
  ./dvm-sync.sh <command>

${GREEN}Commands:${NC}
  clone               Clone all repos from $ORG, then restore working branches
  pull                Pull (rebase + autostash) latest changes from all repos
  push                Push local changes + snapshot working branches
  status              Show git status for all repos
  snapshot            Record each repo's current branch to the manifest
  checkout            Restore each repo to its recorded working branch
  switch-protocol     Switch all remotes between ssh and https
  env-export          Bundle all .env files into an encrypted archive
  env-import          Unpack .env bundle into repos on this machine
  setup               Configure git with DVM-Software credentials
  help                Show this help message

${GREEN}Examples:${NC}
  # First time on new machine (auto-detects ssh vs https):
  ./dvm-sync.sh clone

  # Force HTTPS (no SSH keys needed, uses gh auth):
  GIT_PROTOCOL=https ./dvm-sync.sh clone

  # Switch existing repos to HTTPS:
  ./dvm-sync.sh switch-protocol https

  # Sync .env files to another machine:
  ./dvm-sync.sh env-export          # on source machine (prompts for password)
  # transfer ~/code/dvm-env-bundle.tar.gz.enc to the other machine
  ./dvm-sync.sh env-import          # on target machine (prompts for password)

  # Daily sync:
  ./dvm-sync.sh pull

  # After making changes:
  ./dvm-sync.sh push

  # Moving between laptops:
  #   laptop A:  ./dvm-sync.sh push        # pushes commits + records branches
  #   laptop B:  ./dvm-sync.sh clone       # first time — clones + restores branches
  #   laptop B:  ./dvm-sync.sh pull        # later — rebase latest onto each branch
  #              ./dvm-sync.sh checkout    # re-align branches without pulling

${YELLOW}Note:${NC} branches are tracked in dvm-sync-branches.tsv (in mac-dev-setup).
${YELLOW}Note:${NC} .env / secrets are gitignored — move them with env-export/env-import.

${GREEN}Configuration:${NC}
  Organization: $ORG
  Base Directory: $BASE_DIR
  Protocol: $GIT_PROTOCOL (override with GIT_PROTOCOL=ssh|https)
  Repos: ${REPOS[*]}

${YELLOW}Auth options:${NC}
  SSH:   Configure SSH keys — https://docs.github.com/en/authentication/connecting-to-github-with-ssh
  HTTPS: Install gh CLI and run 'gh auth login' — credentials handled automatically
EOF
      ;;
  esac
}

main "$@"
