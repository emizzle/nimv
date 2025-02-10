#!/bin/bash

# Script version
VERSION="0.0.1"

# Store the starting directory
INITIAL_DIR="$(pwd)"

# Function to show help
show_help() {
    echo "Usage: nimv <command|version-tag>"
    echo ""
    echo "Commands:"
    echo "  installed      List all installed Nim versions"
    echo "  available      List all available Nim versions"
    echo "  current        Show current Nim version"
    echo "  --version      Show nimv version"
    echo "  --help         Show this help message"
    echo ""
    echo "Parameters:"
    echo "  version-tag    The Nim version to install (e.g., v2.0.14, v2.2.0)"
    echo ""
    echo "Examples:"
    echo "  nimv v2.0.14     Install Nim version 2.0.14"
    echo "  nimv installed   List installed versions"
    cd "$INITIAL_DIR"
}

# Shows current version
show_nimv_version() {
    echo "$VERSION"
}

# Function to show available versions
show_available_versions() {
    echo "Getting list of available Nim versions..."

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || { cd "$INITIAL_DIR"; exit 1; }

    # Clone repository and get tags
    git clone --quiet https://github.com/nim-lang/Nim
    cd Nim || { cd "$INITIAL_DIR"; exit 1; }
    echo "Available versions:"
    git tag | grep "^v" | sort -V

    # Clean up
    cd "$INITIAL_DIR"
    rm -rf "$TEMP_DIR"
}

# Function to list installed versions
show_installed_versions() {
    echo "Installed Nim versions:"

    # Get the current version path from choosenim and strip ANSI codes
    current_path=""
    if command -v choosenim &> /dev/null; then
        current_path=$(choosenim show | sed -n '2p' | awk '{print $3}' | sed 's/\x1b\[[0-9;]*m//g')
    fi

    if [ -d "$HOME/.choosenim/nimv" ]; then
        # Find all directories that contain a Nim/bin/nim executable
        find "$HOME/.choosenim/nimv" -type f -path "*/Nim/bin/nim" | while read -r nim_path; do
            version_dir=$(echo "$nim_path" | sed -n 's|.*/nimv/\([^/]*\)/Nim/bin/nim|\1|p')
            install_path=$(echo "$nim_path" | sed 's|/bin/nim$||')

            # Add asterisk if this is the current version
            if [ "$install_path" = "$current_path" ]; then
                echo " * $version_dir (current)"
            else
                echo "   $version_dir"
            fi
        done | sort -V
    else
        echo "  No versions found in $HOME/.choosenim/nimv"
    fi
}

show_current_version() {
    if ! command -v choosenim &> /dev/null; then
        echo "Error: choosenim not found"
        return 1
    fi

    current_path=$(choosenim show | sed -n '2p' | awk '{print $3}' | sed 's/\x1b\[[0-9;]*m//g')
    if [ -n "$current_path" ]; then
        version=$(echo "$current_path" | sed -n 's|.*/nimv/\([^/]*\)/Nim$|\1|p')
        if [ -n "$version" ]; then
            echo "$version"
        else
            echo "No version currently selected"
        fi
    else
        echo "No version currently selected"
    fi
}

# Function to validate version format
validate_version() {
    local version=$1
    if ! [[ $version =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Error: Invalid version format '$version'"
        echo "Version must be in format 'vX.Y.Z' or 'vX.Y' where X, Y, and Z are numbers"
        echo "Examples: v2.0.14, v2.2.0, v1.6"
        cd "$INITIAL_DIR"
        exit 1
    fi
}

# Handle help
if [ "$1" = "--help" ] || [ $# -eq 0 ]; then
    show_help
    cd "$INITIAL_DIR"
    exit 0
# Handle version command
elif [ "$1" = "--version" ]; then
    show_nimv_version
    cd "$INITIAL_DIR"
    exit 0
# Handle installed command
elif [ "$1" = "installed" ]; then
    show_installed_versions
    cd "$INITIAL_DIR"
    exit 0
# Handle available command
elif [ "$1" = "available" ]; then
    show_available_versions
    cd "$INITIAL_DIR"
    exit 0
# Handle current command
elif [ "$1" = "current" ]; then
    show_current_version
    cd "$INITIAL_DIR"
    exit 0
# Validate version format for installation
elif [[ $1 =~ ^v ]]; then
    validate_version "$1"
    VERSION_TAG="$1"
else
    echo "Error: Invalid command or version format '$1'"
    echo "Use --help for usage information"
    cd "$INITIAL_DIR"
    exit 1
fi

# Function to detect OS and provide PATH instructions
provide_path_instructions() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "For macOS, add this line to your ~/.zshrc or ~/.bash_profile:"
        echo "    export PATH=\$HOME/.nimble/bin:\$PATH"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "For Linux, add this line to your ~/.bashrc:"
        echo "    export PATH=\$HOME/.nimble/bin:\$PATH"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "For Windows, add this path to your system environment variables:"
        echo "    %USERPROFILE%\\.nimble\\bin"
    else
        echo "Add this directory to your PATH:"
        echo "    \$HOME/.nimble/bin"
    fi
}

# Check if choosenim is installed and in PATH
NEEDS_PATH_WARNING=false
if ! command -v choosenim &> /dev/null; then
    echo "choosenim not found, installing..."

    # Check for curl or wget
    if command -v curl &> /dev/null; then
        if ! curl https://nim-lang.org/choosenim/init.sh -sSf | sh; then
            echo "Error: Failed to install choosenim using curl"
            cd "$INITIAL_DIR"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -qO- https://nim-lang.org/choosenim/init.sh | sh; then
            echo "Error: Failed to install choosenim using wget"
            cd "$INITIAL_DIR"
            exit 1
        fi
    else
        echo "Error: Neither curl nor wget found. Please install either curl or wget and try again"
        cd "$INITIAL_DIR"
        exit 1
    fi

    # Temporarily add choosenim to PATH for this script
    export PATH="$HOME/.nimble/bin:$PATH"

    # Check if choosenim is now available
    if ! command -v choosenim &> /dev/null; then
        echo "Error: choosenim installation appeared to succeed but choosenim command not found"
        echo "Please ensure choosenim is properly installed and try again"
        provide_path_instructions
        cd "$INITIAL_DIR"
        exit 1
    fi
    NEEDS_PATH_WARNING=true
else
    echo "choosenim is already installed"
fi

# Set up directory paths
CHOOSENIM_DIR="$HOME/.choosenim/nimv/$VERSION_TAG"
NIM_DIR="$CHOOSENIM_DIR/Nim"
NIM_BIN_PATH="$NIM_DIR/bin"

# Check if this version is already installed and working
if [ -f "$NIM_BIN_PATH/nim" ] && [ -x "$NIM_BIN_PATH/nim" ]; then
    echo "Nim $VERSION_TAG is already installed at $NIM_BIN_PATH"
    echo "Setting choosenim to use existing Nim build '$NIM_DIR'..."
    choosenim "$NIM_DIR"
    exit 0
fi

# If we get here, we need to install the version
echo "Installing Nim $VERSION_TAG..."

# Create version-specific directory if it doesn't exist
if [ ! -d "$CHOOSENIM_DIR" ]; then
    mkdir -p "$CHOOSENIM_DIR"
fi

# Change to the directory and clone/build Nim
cd "$CHOOSENIM_DIR" || exit 1
if [ ! -d "Nim" ]; then
    git clone https://github.com/nim-lang/Nim
fi
cd Nim || exit 1

# Fetch all tags and checkout the specified version
git fetch --tags
if ! git tag | grep -q "^$VERSION_TAG\$"; then
    echo "Error: Version tag '$VERSION_TAG' not found"
    echo "Available versions:"
    git tag | grep "^v" | sort -V
    cd "$HOME" || exit 1
    rm -rf "$CHOOSENIM_DIR"
    exit 1
fi

git checkout "$VERSION_TAG"
sh build_all.sh

# Point choosenim to the newly built Nim
if [ -d "$NIM_BIN_PATH" ]; then
    echo "Setting choosenim to use custom Nim build '$NIM_DIR'..."
    choosenim "$NIM_DIR"
else
    echo "Error: Nim binary not found at $NIM_BIN_PATH"
    cd "$INITIAL_DIR"
    exit 1
fi

# Show PATH warning if needed
if [ "$NEEDS_PATH_WARNING" = true ]; then
    echo ""
    echo "WARNING: choosenim is not in your PATH"
    echo "You must ensure that the Nimble bin dir is in your PATH"
    echo ""
    provide_path_instructions
    echo ""
    echo "After adding to PATH, you may need to restart your terminal"
fi

# Return to initial directory at the end
cd "$INITIAL_DIR"