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
REPOS=(
  "dvm-fullstack"
  "smb-tax"
  "md-reader"
  "mermaid-thing"
)

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

clone_repos() {
  print_header "🔄 Cloning all repos from $ORG"
  
  cd "$BASE_DIR"
  
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    
    if [ -d "$local_path" ]; then
      print_info "$repo already exists at $local_path (skipping clone)"
      continue
    fi
    
    echo ""
    echo "📦 Cloning $repo..."
    git clone "git@github.com:$ORG/$repo.git" "$repo"
    print_success "$repo cloned"
  done
  
  echo ""
  print_success "All repos cloned!"
}

pull_repos() {
  print_header "⬇️  Pulling latest from all repos"
  
  local total=0
  local updated=0
  
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    
    if [ ! -d "$local_path/.git" ]; then
      print_error "$repo not found at $local_path (run 'clone' first)"
      continue
    fi
    
    total=$((total + 1))
    echo ""
    echo "📦 Pulling $repo..."
    
    cd "$local_path"
    if git pull; then
      print_success "$repo pulled"
      updated=$((updated + 1))
    else
      print_error "Failed to pull $repo"
    fi
  done
  
  echo ""
  print_success "Pulled $updated/$total repos"
}

push_repos() {
  print_header "⬆️  Pushing changes from all repos"
  
  local total=0
  local pushed=0
  
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    
    if [ ! -d "$local_path/.git" ]; then
      print_error "$repo not found at $local_path"
      continue
    fi
    
    total=$((total + 1))
    echo ""
    echo "📦 Checking $repo..."
    
    cd "$local_path"
    
    # Check if there are changes to push
    if [ -z "$(git status --porcelain)" ]; then
      print_info "$repo has no changes"
      continue
    fi
    
    # Commit changes if there are unstaged changes
    if ! git diff-index --quiet HEAD --; then
      print_info "Found changes in $repo, committing..."
      git add .
      git commit -m "Auto-sync: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Push changes
    if git push; then
      print_success "$repo pushed"
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
  
  for repo in "${REPOS[@]}"; do
    local_path="$BASE_DIR/$repo"
    
    if [ ! -d "$local_path/.git" ]; then
      print_error "$repo not found at $local_path"
      continue
    fi
    
    echo ""
    echo "📦 $repo:"
    cd "$local_path"
    git status --short || true
  done
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
