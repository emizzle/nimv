#!/bin/bash

# Script version
VERSION=0.0.8

# Store the starting directory
INITIAL_DIR="$(pwd)"

# Set up colors and symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
TICK="✓"
CROSS="✗"
WARN="⚠"

# Function to show success/failure/warning
show_status() {
    local message="$1"
    local status="$2"  # can be "success", "failure", or "warning"
    case "$status" in
        "success")
            echo -e "${GREEN}${TICK}${NC} ${CYAN}$message${NC}"
            ;;
        "failure")
            echo -e "${RED}${CROSS}${NC} ${CYAN}$message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}${WARN}${NC} ${CYAN}$message${NC}"
            ;;
    esac
}

# Function to show help
show_help() {
    echo "Usage: $0 <command|version-tag>"
    echo ""
    echo "Commands:"
    echo "  installed      List all installed Nim versions"
    echo "  available      List all available Nim versions"
    echo "  current        Show current Nim version"
    echo "  check          Verify correct installation and versions"
    echo "  --version      Show script version"
    echo "  --help         Show this help message"
    echo ""
    echo "Parameters:"
    echo "  version-tag    The Nim version to install (e.g., 2.0.14, 2.2.0)"
    echo ""
    echo "Examples:"
    echo "  $0 2.0.14      Install Nim version 2.0.14"
    echo "  $0 installed   List installed versions"
}

# Function to list installed versions
show_installed_versions() {
    echo "Installed Nim versions:"

    # Get the current version path
    local current_path=""
    local nim_link="$HOME/.nimble/bin/nim"
    if [ -L "$nim_link" ]; then
        current_path=$(readlink -f "$nim_link")
    fi

    if [ -d "$HOME/.nimv" ]; then
        # First collect and sort versions
        versions_list=$(find "$HOME/.nimv" -type f -path "*/Nim/bin/nim" | \
            sed -n 's|.*/\.nimv/\([^/]*\)/Nim/bin/nim|\1|p' | \
            sort -V)

        # Then format output with asterisk
        while IFS= read -r version; do
            version_path="$HOME/.nimv/$version/Nim/bin/nim"
            if [ "$version_path" = "$current_path" ]; then
                echo " * $version (current)"
            else
                echo "   $version"
            fi
        done <<< "$versions_list"
    else
        echo "  No versions found in $HOME/.nimv"
    fi
}

# Function to show available versions
show_available_versions() {
    echo "Getting list of available Nim versions..."
    git ls-remote --tags https://github.com/nim-lang/Nim 'v*' | \
        sed 's/.*refs\/tags\///' | \
        grep -v '{}' | \
        sed 's/^v//' | \
        sort -V
}

# Function to show current version
show_current_version() {
    local nim_link="$HOME/.nimble/bin/nim"
    if [ -L "$nim_link" ]; then
        local target=$(readlink -f "$nim_link")
        version=$(echo "$target" | sed -n 's|.*/\.nimv/\([^/]*\)/Nim/bin/nim|\1|p')
        if [ -n "$version" ]; then
            echo "$version"
        else
            echo "No version currently selected"
        fi
    else
        echo "No version currently selected"
    fi
}

# Detect current platform
get_platform() {
    local platform=""
    local arch=""

    # Get OS
    case "$(uname -s)" in
        Darwin*)
            platform="Mach-O";;
        Linux*)
            platform="ELF";;
        *)
            platform="unknown";;
    esac

    # Get architecture
    case "$(uname -m)" in
        x86_64*)
            arch="x86_64";;
        aarch64*|arm64)
            arch="arm64";;
        *)
            arch="unknown";;
    esac

    echo "$platform $arch"
}

# Function to create symlinks for Nim binaries
create_symlinks() {
    local bin_dir="$1"
    local nimble_dir="$HOME/.nimble/bin"

    # Create .nimble/bin if it doesn't exist
    mkdir -p "$nimble_dir"

    # List of binaries to symlink
    local binaries=("nim" "nim-gdb" "nimble" "nimgrep" "nimpretty" "nimsuggest" "testament" "atlas")

    # Remove existing symlinks
    for binary in "${binaries[@]}"; do
        if [ -L "$nimble_dir/$binary" ]; then
            rm -f "$nimble_dir/$binary"
        fi
    done

    # Create new symlinks
    for binary in "${binaries[@]}"; do
        if [ -f "$bin_dir/$binary" ]; then
            ln -sf "$bin_dir/$binary" "$nimble_dir/$binary"
        fi
    done

    # Check if .nimble/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.nimble/bin:"* ]]; then
        echo ""
        echo "=============== ⛔️ SETUP INCOMPLETE: PATH REQUIRES MODIFICATION ⛔️ =================="
        echo "| $HOME/.nimble/bin MUST be added to PATH                                           |"
        echo "|                                                                                   |"
        echo "| To add it permanently, update PATH in your shell's config file:                   |"
        case "$SHELL" in
            *bash)
                echo -e "|   ${CYAN}echo 'export PATH=\$HOME/.nimble/bin:\$PATH' >> ~/.bashrc${NC}                         |"
                ;;
            *zsh)
                echo -e "|   ${CYAN}echo 'export PATH=\$HOME/.nimble/bin:\$PATH' >> ~/.zshrc${NC}                          |"
                ;;
            *)
                echo -e "|   ${CYAN}Add 'export PATH=\$HOME/.nimble/bin:\$PATH' to your shell's config file${NC}           |"
                ;;
        esac
        echo "|                                                                                   |"
        echo -e "| Then restart your terminal or run: ${CYAN}source ~/.bashrc${NC} (or your shell's equivalent)  |"
        echo "====================================================================================="
    fi
}

check_installation() {
    local has_error=false

    # Check 1: Binary architecture and path
    local current_version=$(show_current_version)
    local current_platform=$(get_platform)
    local file_output
    if [ -z "$current_version" ] || [ "$current_version" = "No version currently selected" ]; then
        show_status "Checking nim binary platform matches current platform" "failure"
        echo "  Error: No nim version currently selected"
        has_error=true
    elif ! file_output=$(file -L "$(which nim 2>/dev/null)" 2>/dev/null); then
        show_status "Checking nim binary platform matches current platform" "failure"
        echo "  Error: nim not found in PATH"
        has_error=true
    else
        case "$current_platform" in
            "Mach-O arm64")
                if ! echo "$file_output" | grep -q "Mach-O.*arm64"; then
                    show_status "Checking nim binary platform matches current platform" "failure"
                    echo "  Error: Expected Mach-O arm64 binary but got: $file_output"
                    has_error=true
                else
                    show_status "Checking nim binary platform matches current platform" "success"
                    echo "  $file_output"
                fi
                ;;
            "Mach-O x86_64")
                if ! echo "$file_output" | grep -q "Mach-O.*x86_64"; then
                    show_status "Checking nim binary platform matches current platform" "failure"
                    echo "  Error: Expected Mach-O x86_64 binary but got: $file_output"
                    has_error=true
                else
                    show_status "Checking nim binary platform matches current platform" "success"
                    echo "  $file_output"
                fi
                ;;
            "ELF x86_64")
                if ! echo "$file_output" | grep -q "ELF.*x86_64"; then
                    show_status "Checking nim binary platform matches current platform" "failure"
                    echo "  Error: Expected ELF x86_64 binary but got: $file_output"
                    has_error=true
                else
                    show_status "Checking nim binary platform matches current platform" "success"
                    echo "  $file_output"
                fi
                ;;
            "ELF arm64")
                if ! echo "$file_output" | grep -q "ELF.*aarch64"; then
                    show_status "Checking nim binary platform matches current platform" "failure"
                    echo "  Error: Expected ELF arm64 binary but got: $file_output"
                    has_error=true
                else
                    show_status "Checking nim binary platform matches current platform" "success"
                    echo "  $file_output"
                fi
                ;;
            *)
                show_status "Checking nim binary platform matches current platform" "failure"
                echo "  Error: Unknown platform: $current_platform"
                has_error=true
                ;;
        esac
    fi

    # Check 2: Version match
    if [ -z "$current_version" ] || [ "$current_version" = "No version currently selected" ]; then
        show_status "Checking nim binary version matches nim version selected with nimv" "failure"
        echo "  Error: No nim version currently selected"
        has_error=true
    else
        local nim_version
        nim_version=$(nim --version 2>/dev/null | head -n1 | sed 's/Nim Compiler Version \([0-9.]*\).*/\1/')
        if [ "$nim_version" != "$current_version" ]; then
            show_status "Checking nim binary version matches nim version selected with nimv" "failure"
            echo "  Currently selected version: $current_version"
            echo "  Nim binary reports: $nim_version"
            has_error=true
        else
            show_status "Checking nim binary version matches nim version selected with nimv" "success"
            echo "  Version matches: $nim_version"
        fi
    fi

    # Check 3: nimv version against latest release
    local latest_version
    latest_version=$(git ls-remote --tags https://github.com/emizzle/nimv | \
                    grep -o '[0-9][0-9.]*$' | \
                    sort -V | \
                    tail -n1)

    if printf '%s\n' "$latest_version" "$VERSION" | sort -V | head -n1 | grep -q "^$latest_version$"; then
        show_status "Checking if nimv has available updates" "success"
        echo "  Currently up-to-date: $VERSION"
    else
        show_status "Checking if nimv has available updates" "warning"
        echo "  Current version: $VERSION"
        echo "  Latest version: $latest_version"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "To update, run:"
            echo "  brew update"
            echo "  brew upgrade nimv"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "To update, run:"
            echo "  sudo apt update"
            echo "  sudo apt upgrade nimv"
        fi
    fi

    [ "$has_error" = false ]
    return $?
}

# Function to validate version format
validate_version() {
    local version=$1
    if ! [[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: Invalid version format '$version'"
        echo "Version must be in format 'X.Y.Z' or 'X.Y' where X, Y, and Z are numbers"
        echo "Examples: 2.0.14, 2.2.0, 1.6"
        exit 1
    fi
}

# Process commands
if [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    show_help
    exit 0
elif [ "$1" = "installed" ]; then
    show_installed_versions
    exit 0
elif [ "$1" = "available" ]; then
    show_available_versions
    exit 0
elif [ "$1" = "current" ]; then
    show_current_version
    exit 0
elif [ "$1" = "check" ]; then
    check_installation
    exit $?
elif [ "$1" = "--version" ]; then
    echo "$VERSION"
    exit 0
elif [[ $1 =~ ^[0-9] ]]; then
    validate_version "$1"
    VERSION_TAG="v$1"
else
    echo "Error: Invalid command or version format '$1'"
    echo "Use --help for usage information"
    exit 1
fi

# Set up directory paths after command validation
NIMV_DIR="$HOME/.nimv/$1"
NIM_DIR="$NIMV_DIR/Nim"
NIM_BIN_PATH="$NIM_DIR/bin"

# Check if version is already installed
if [ -f "$NIM_BIN_PATH/nim" ] && [ -x "$NIM_BIN_PATH/nim" ]; then
    echo "Nim version $1 is already installed at $NIM_BIN_PATH"
    echo "Setting version $1 as current version..."
    create_symlinks "$NIM_BIN_PATH"
    echo "Done."
    exit 0
fi

# Install new version
echo "Installing Nim version $1..."

# Create version-specific directory if it doesn't exist
if [ ! -d "$NIMV_DIR" ]; then
    mkdir -p "$NIMV_DIR"
fi

# Clone and build Nim
cd "$NIMV_DIR" || exit 1
if [ ! -d "Nim" ]; then
    git clone https://github.com/nim-lang/Nim
fi
cd Nim || exit 1

# Fetch tags and checkout version
git fetch --tags
if ! git tag | grep -q "^$VERSION_TAG\$"; then
    echo "Error: Version tag '$VERSION_TAG' not found"
    echo "Available versions:"
    git tag | grep "^v" | sed 's/^v//' | sort -V
    cd "$INITIAL_DIR"
    rm -rf "$NIMV_DIR"
    exit 1
fi

git checkout "$VERSION_TAG"
sh build_all.sh

# Create symlinks and clean up
if [ -d "$NIM_BIN_PATH" ]; then
    echo "Setting version $1 as current version..."
    create_symlinks "$NIM_BIN_PATH"

    echo "Cleaning up installation directory..."
    cd "$NIM_DIR" || exit 1
    find . -mindepth 1 -maxdepth 1 ! -name 'bin' ! -name 'lib' ! -name 'dist' ! -name 'config' ! -name 'compiler' -exec rm -rf {} +
    find dist -mindepth 1 -maxdepth 1 ! -name 'checksums' -exec rm -rf {} +
    rm -f "$NIM_BIN_PATH"/nim_csources*

    echo "Done."
    cd "$INITIAL_DIR"
else
    echo "Error: Nim binary not found at $NIM_BIN_PATH"
    cd "$INITIAL_DIR"
    exit 1
fi
