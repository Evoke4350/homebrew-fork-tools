#!/bin/bash
# fork-tools installer - One-command installation
# Usage: curl -fsSL https://raw.githubusercontent.com/Evoke4350/homebrew-fork-tools/main/install.sh | sh

set -eo pipefail

# Colors for output
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# Configuration
REPO="Evoke4350/homebrew-fork-tools"
VERSION="${FORK_TOOLS_VERSION:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${VERSION}"
INSTALL_DIR="${FORK_TOOLS_DIR:-$HOME/.local/bin}"
mkdir -p "$INSTALL_DIR"

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Header
cat <<'EOF'
     _____ _____ __  __          _____
    / ____|  __ \  \/  |   /\   / ____|
   | |    | |__) |\   / |  /  \ | |     ____
   | |    |  ___/ \  /|  / /\ \| |    / _ \
   | |____| |     /  \/ / ____ \ |___| (_) |
    \_____|_|    /_/\_\/_/    \_\_____\___/

    Fork management for developers
EOF
echo ""

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*)    PLATFORM="macos"; PKGMGR="brew" ;;
        Linux*)     PLATFORM="linux"
                    if command -v apt-get >/dev/null 2>&1; then PKGMGR="apt"
                    elif command -v yum >/dev/null 2>&1; then PKGMGR="yum"
                    elif command -v pacman >/dev/null 2>&1; then PKGMGR="pacman"
                    else PKGMGR="unknown"; fi
                    ;;
        MINGW*|MSYS*) PLATFORM="windows"; PKGMGR="none" ;;
        *)          PLATFORM="unknown"; PKGMGR="none" ;;
    esac
}

# Check dependencies
check_deps() {
    local missing=()
    for cmd in git curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_err "Missing required dependencies: ${missing[*]}"
        echo "  Please install and try again."
        exit 1
    fi
}

# Download script
download_script() {
    local script="$1"
    local url="${BASE_URL}/${script}"

    log_info "Downloading ${script}..."
    if curl -fsSL "$url" -o "${INSTALL_DIR}/${script}" 2>/dev/null; then
        chmod +x "${INSTALL_DIR}/${script}"
        log_ok "Installed ${script}"
    else
        log_err "Failed to download ${script}"
        return 1
    fi
}

# Setup shell integration
setup_shell() {
    local shell="$1"
    local config="$2"
    local export_line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ ! -f "$config" ]]; then
        touch "$config"
    fi

    if ! grep -q "\.local/bin" "$config" 2>/dev/null; then
        echo "" >> "$config"
        echo "# fork-tools" >> "$config"
        echo "$export_line" >> "$config"
        log_ok "Added to ${config}"
    else
        log_info "Already in ${config}"
    fi
}

# Main installation
main() {
    detect_platform
    check_deps

    log_info "Platform: ${PLATFORM}"
    log_info "Install directory: ${INSTALL_DIR}"
    echo ""

    # Download scripts
    local scripts=("fork-report.sh" "fork-check.sh" "fork-watcher.sh")
    local failed=()

    for script in "${scripts[@]}"; do
        if ! download_script "$script"; then
            failed+=("$script")
        fi
    done

    echo ""

    # Check PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log_warn "INSTALL_DIR not in PATH"

        case "${SHELL:-}" in
            */zsh)
                setup_shell zsh "$HOME/.zshrc"
                log_info "Run: source ~/.zshrc or restart shell"
                ;;
            */bash)
                setup_shell bash "$HOME/.bashrc"
                log_info "Run: source ~/.bashrc or restart shell"
                ;;
            *)
                echo ""
                log_info "Add this to your shell config:"
                echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
                ;;
        esac
    else
        log_ok "INSTALL_DIR already in PATH"
    fi

    echo ""

    # Summary
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo -e "${BOLD}Installation complete!${NC}"
        echo ""
        echo "Try it:"
        echo "  ${CYAN}fork-report --help${NC}"
        echo ""
        echo "Set your GitHub usernames:"
        echo "  ${CYAN}export GITHUB_USERNAMES=\"yourname\"${NC}"
        echo ""
        echo "Generate a report:"
        echo "  ${CYAN}fork-report > ~/fork-status.md${NC}"
        echo ""
        echo "Docs: https://evoke4350.github.io/homebrew-fork-tools"
    else
        log_err "Some installations failed: ${failed[*]}"
        exit 1
    fi
}

# Run
main "$@"
