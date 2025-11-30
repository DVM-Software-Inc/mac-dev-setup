# macOS Development Environment Setup

Replicate the M4 Mac dev setup on another machine.

## Prerequisites

- macOS (Apple Silicon or Intel)
- Admin access
- Internet connection

---

## 1. Xcode Command Line Tools

```bash
xcode-select --install
```

---

## 2. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

---

## 3. asdf (Version Manager)

```bash
brew install asdf

# Add to shell
echo '. $(brew --prefix asdf)/libexec/asdf.sh' >> ~/.zshrc
source ~/.zshrc
```

### Install plugins and runtimes

```bash
# Add plugins
asdf plugin add java
asdf plugin add python
asdf plugin add nodejs
asdf plugin add golang

# Install runtimes
asdf install java temurin-21.0.2+13.0.LTS
asdf install python 3.12.0
asdf install nodejs lts
asdf install golang latest

# Set global defaults
cat > ~/.tool-versions << 'EOF'
java temurin-21.0.2+13.0.LTS
python 3.12.0
nodejs lts
golang 1.25.4
EOF
```

---

## 4. Git Configuration

```bash
git config --global user.name "DVM-Software"
git config --global user.email "DVM-Software@users.noreply.github.com"
git config --global init.defaultBranch main
```

---

## 5. SSH Keys

### Generate new key

```bash
ssh-keygen -t ed25519 -C "DVM-Software@users.noreply.github.com" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Add to GitHub

```bash
cat ~/.ssh/id_ed25519.pub
# Copy output → https://github.com/settings/keys → New SSH key
```

### Test GitHub connection

```bash
ssh -T git@github.com
```

### Configure VPS access (Contabo)

```bash
# Add to ~/.ssh/config
cat >> ~/.ssh/config << 'EOF'

Host contabo
    HostName 194.238.24.254
    User root
    IdentityFile ~/.ssh/id_ed25519
EOF

# Copy key to VPS (will prompt for password once)
ssh-copy-id contabo

# Test
ssh contabo "hostname"
```

---

## 6. Folder Structure

```bash
mkdir -p ~/code/{go,java,python,typescript/react,typescript/angular,infra,scripts,samples,dotfiles,setup}
```

---

## 7. Dev Tools

```bash
# Common CLI tools
brew install git wget gnupg gawk

# Docker Desktop (optional for local dev)
brew install --cask docker

# Python tools
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install --user pipx poetry black isort 'uvicorn[standard]' fastapi

# Node tools
npm install -g pnpm@latest @angular/cli@latest
```

---

## 8. VS Code

### Install VS Code

Download from https://code.visualstudio.com/ or:

```bash
brew install --cask visual-studio-code
```

### Add CLI to PATH

In VS Code: `Cmd+Shift+P` → `Shell Command: Install 'code' command in PATH`

### Install extensions

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension redhat.java
code --install-extension vmware.vscode-spring-boot
code --install-extension golang.Go
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension angular.ng-template
code --install-extension ms-vscode-remote.remote-ssh
```

---

## 9. Verify Installation

```bash
echo "=== Versions ===" && \
java -version 2>&1 | head -1 && \
python3 --version && \
node -v && \
go version && \
git --version && \
code --version | head -1
```

Expected output:
```
=== Versions ===
openjdk version "21.0.2" ...
Python 3.12.0
v22.x.x
go version go1.25.x darwin/arm64
git version 2.x.x
1.x.x
```

---

## 10. Sync Projects

If your projects are on the other Mac, either:

**Option A: Git clone from GitHub**
```bash
cd ~/code/python
git clone git@github.com:DVM-Software/your-repo.git
```

**Option B: rsync from other Mac** (same network)
```bash
# On NEW Mac, pull from OLD Mac
rsync -avz --progress oldmac:~/code/ ~/code/
```

**Option C: External drive / AirDrop**

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `ssh contabo` | Connect to VPS |
| `asdf list` | Show installed versions |
| `asdf install <plugin> <version>` | Install a runtime |
| `code .` | Open current folder in VS Code |
| `Cmd+Shift+P` → Remote-SSH | Connect to VPS in VS Code |

---

## VPS Info (Contabo)

- **IP**: 194.238.24.254
- **User**: root
- **Stack**: DokPloy + Traefik + Docker
- **Services**: Postgres, Mongo, MSSQL, Redis, Authentik

---

*Generated: November 30, 2025*
