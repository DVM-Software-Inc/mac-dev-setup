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

# This script lives in mac-dev-setup — it syncs itself along with everything else
REPOS=(
  "mac-dev-setup"
  "buktub"
  "cc_dvm"
  "chatactorai"
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
  "makeroo"
  "md-reader"
  "mermaid-thing"
  "qe_automaton"
  "setup"
  "smb-tax"
  "stock-analyst"
  "tattoo-on-me"
  "telegram"
  "todo"
  "vault"
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
    print_info "GitHub CLI not found. Continuing without it (you may need SSH keys configured)"
  fi
  
  if [ ! -d "$BASE_DIR" ]; then
    print_info "Creating $BASE_DIR..."
    mkdir -p "$BASE_DIR"
  fi
}

get_repo_org() {
  local repo="$1"
  case "$repo" in
    cc_dvm) echo "DVM-Software" ;;
    *)      echo "$ORG" ;;
  esac
}

clone_repos() {
  print_header "🔄 Cloning all repos from $ORG"

  cd "$BASE_DIR"

  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    local repo_org
    repo_org=$(get_repo_org "$repo")

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
        gh repo create "$repo_org/$repo" --private --source=. --push
        print_success "$repo initialized and pushed to $repo_org/$repo"
      else
        print_error "$repo initialized locally but gh CLI needed to create remote"
      fi
      cd "$BASE_DIR"
      continue
    fi

    echo ""
    echo "📦 Cloning $repo..."
    git clone "git@github.com:$repo_org/$repo.git" "$repo"
    print_success "$repo cloned"
  done

  echo ""
  print_success "All repos cloned!"
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

    if git pull; then
      print_success "$repo pulled"
      updated=$((updated + 1))
    else
      print_error "Failed to pull $repo"
    fi
  done

  echo ""
  print_success "Pulled $updated/$total repos ($skipped skipped — no remote/upstream)"
}

push_repos() {
  print_header "⬆️  Pushing changes from all repos"

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
        gh repo create "$repo_org/$repo" --private --source=. --push
        print_success "$repo created and pushed to $repo_org/$repo"
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
  clone       Clone all repos from $ORG (initial setup on new machine)
  pull        Pull latest changes from all repos
  push        Push local changes to all repos
  status      Show git status for all repos
  setup       Configure git with DVM-Software credentials
  help        Show this help message

${GREEN}Examples:${NC}
  # First time on new machine:
  ./dvm-sync.sh clone
  
  # Daily sync:
  ./dvm-sync.sh pull
  
  # After making changes:
  ./dvm-sync.sh push

${GREEN}Configuration:${NC}
  Organization: $ORG
  Base Directory: $BASE_DIR
  Repos: ${REPOS[*]}

${YELLOW}Note:${NC} Make sure you have SSH keys configured for GitHub:
  https://docs.github.com/en/authentication/connecting-to-github-with-ssh
EOF
      ;;
  esac
}

main "$@"
