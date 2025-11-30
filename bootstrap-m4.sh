#!/usr/bin/env zsh
# bootstrap-m4.sh — One-shot macOS M4 developer bootstrap (adjusted for robustness)
# Usage: ~/bootstrap-m4.sh [--yes] [--dry-run] [--skip-vscode-ext]

SCRIPT_LOG="$HOME/bootstrap-m4.log"
BACKUP_DIR="$HOME/bootstrap-m4-backups-$(date -u +%Y%m%dT%H%M%SZ)"
DRY_RUN=0
NON_INTERACTIVE=0
SKIP_VSCODE_EXT=0

confirm() {
  [[ $NON_INTERACTIVE -eq 1 ]] && return 0
  read -r "resp?$1 [y/N]: "
  [[ "$resp" =~ ^[yY] ]]
}

_log() { echo "[BOOTSTRAP] $*" | tee -a "$SCRIPT_LOG"; }

while [[ ${1-} != "" ]]; do
  case $1 in
    --yes|--non-interactive) NON_INTERACTIVE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --skip-vscode-ext) SKIP_VSCODE_EXT=1 ;;
    --help) echo "Usage: $0 [--yes] [--dry-run] [--skip-vscode-ext]"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
  shift
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    _log "DRY RUN: $*"
  else
    _log "RUN: $*"
    eval "$@" || _log "WARNING: command failed: $*"
  fi
}

mkdir -p "$BACKUP_DIR"
: > "$SCRIPT_LOG"
_log "Starting bootstrap — log: $SCRIPT_LOG"

# 1) System checks
_log "Checking macOS architecture"
_log "OS: $(uname -s)  ARCH: $(uname -m)"

# 2) Xcode CLT
_log "Verifying Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  _log "Xcode CLT not found — installing (you may see a dialog)"
  xcode-select --install 2>/dev/null || true
  _log "If a dialog appeared, complete it and re-run this script."
else
  _log "Xcode CLT found at $(xcode-select -p)"
fi

# 3) Homebrew
_log "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    _log "Installing Homebrew"
    run '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
_log "Homebrew: $(brew --version 2>/dev/null | head -n1 || echo 'not found')"

# 4) Create ~/code structure
_log "Creating workspace under ~/code"
CODE_DIR="$HOME/code"
run "mkdir -p $CODE_DIR/{backend/java,backend/python,backend/go,frontend/react,frontend/angular,infra,ai-tools,samples,dotfiles,scripts}"

# 5) Install asdf
_log "Checking asdf"
if ! command -v asdf >/dev/null 2>&1; then
  run "brew install asdf"
fi
# Source asdf for this session
if [[ -f "$(brew --prefix asdf 2>/dev/null)/libexec/asdf.sh" ]]; then
  source "$(brew --prefix asdf)/libexec/asdf.sh"
fi
_log "asdf version: $(asdf --version 2>/dev/null || echo 'not available yet')"

# 6) Backup and update ~/.zshrc
ZSHRC="$HOME/.zshrc"
[[ -f "$ZSHRC" ]] && cp "$ZSHRC" "$BACKUP_DIR/.zshrc.bak"
if ! grep -q 'asdf.sh' "$ZSHRC" 2>/dev/null; then
  _log "Adding asdf init to ~/.zshrc"
  echo '# asdf init (added by bootstrap-m4.sh)' >> "$ZSHRC"
  echo '. $(brew --prefix asdf)/libexec/asdf.sh 2>/dev/null || true' >> "$ZSHRC"
fi
if ! grep -q 'alias py=' "$ZSHRC" 2>/dev/null; then
  echo 'alias py=python3  # added by bootstrap-m4.sh' >> "$ZSHRC"
  _log "Added alias py -> python3"
fi

# 7) asdf plugins
_log "Adding asdf plugins"
for p in java nodejs python golang maven gradle; do
  asdf plugin add "$p" 2>/dev/null || true
done

# 8) Install language runtimes via asdf
_log "Installing Java (Temurin 21)"
asdf install java temurin-21.0.2+13.0.LTS 2>/dev/null || asdf install java latest 2>/dev/null || _log "Java install needs manual check"
asdf global java temurin-21.0.2+13.0.LTS 2>/dev/null || true

_log "Installing Python 3.12"
asdf install python 3.12.0 2>/dev/null || asdf install python latest 2>/dev/null || _log "Python install needs manual check"
asdf global python 3.12.0 2>/dev/null || true

_log "Installing Node LTS"
asdf install nodejs lts 2>/dev/null || _log "Node install needs manual check"
asdf global nodejs lts 2>/dev/null || true

_log "Installing Go"
asdf install golang latest 2>/dev/null || _log "Go install needs manual check"
asdf global golang latest 2>/dev/null || true

# 9) Common dev tools
_log "Installing common dev tools (git, wget, gnupg)"
run "brew install git wget gnupg gawk || true"

# 10) Docker Desktop
if ! command -v docker >/dev/null 2>&1; then
  if confirm "Install Docker Desktop?"; then
    run "brew install --cask docker"
    _log "Docker Desktop installed — open it from Applications to finish setup"
  fi
else
  _log "Docker already installed: $(docker --version 2>/dev/null)"
fi

# 11) VS Code CLI
if ! command -v code >/dev/null 2>&1; then
  if [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    _log "Symlinking VS Code CLI"
    sudo ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" /usr/local/bin/code 2>/dev/null || true
  else
    _log "VS Code not found — install it and run 'Shell Command: Install code command in PATH' from Command Palette"
  fi
fi

# 12) Python tools
_log "Installing Python helpers (pipx, poetry, fastapi, uvicorn)"
run "python3 -m pip install --upgrade pip setuptools wheel 2>/dev/null || true"
run "python3 -m pip install --user pipx poetry black isort 'uvicorn[standard]' fastapi 2>/dev/null || true"

# 13) Node tools
_log "Installing Node tools (pnpm, Angular CLI)"
run "npm install -g pnpm@latest @angular/cli@latest 2>/dev/null || true"

# 14) AI tooling (cloud-only)
_log "AI tools setup"
if confirm "Install Kilo CLI?"; then
  run "curl -sS https://kilo.ai/install | bash" || true
fi
if confirm "Install Google Cloud SDK (for Gemini)?"; then
  run "brew install --cask google-cloud-sdk" || true
fi
_log "Anthropic/OpenAI: add API keys to macOS Keychain manually (see README)"

# 15) VS Code extensions
if [[ $SKIP_VSCODE_EXT -eq 0 ]] && command -v code >/dev/null 2>&1; then
  if confirm "Install recommended VS Code extensions?"; then
    for ext in ms-python.python ms-python.vscode-pylance redhat.java vscjava.vscode-spring-boot golang.Go dbaeumer.vscode-eslint esbenp.prettier-vscode angular.ng-template; do
      run "code --install-extension $ext --force" || true
    done
  fi
fi

# 16) Final verification
_log "=== VERIFICATION ==="
_log "Java: $(java -version 2>&1 | head -n1 || echo 'not found')"
_log "Python: $(python3 --version 2>&1 || echo 'not found')"
_log "Node: $(node -v 2>&1 || echo 'not found')"
_log "Go: $(go version 2>&1 || echo 'not found')"
_log "Git: $(git --version 2>&1 || echo 'not found')"
_log "Docker: $(docker --version 2>&1 || echo 'not found')"
_log "VS Code: $(code --version 2>&1 | head -n1 || echo 'not found')"

_log "Bootstrap complete! Open a new terminal to pick up PATH changes."
_log "Log: $SCRIPT_LOG | Backups: $BACKUP_DIR"

cat >> "$HOME/bootstrap-m4.summary.txt" << EOF
Bootstrap completed: $(date)
Log: $SCRIPT_LOG
Backups: $BACKUP_DIR
Next: Add API keys to Keychain, start Docker Desktop, verify tools in new terminal
EOF

exit 0
