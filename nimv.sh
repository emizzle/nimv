#!/bin/bash

# Script version
VERSION="0.0.2"

# Store the starting directory
INITIAL_DIR="$(pwd)"

# Function to show help
show_help() {
   echo "Usage: $0 <command|version-tag>"
   echo ""
   echo "Commands:"
   echo "  installed      List all installed Nim versions"
   echo "  available      List all available Nim versions"
   echo "  current        Show current Nim version"
   echo "  --version      Show script version"
   echo "  --help         Show this help message"
   echo ""
   echo "Parameters:"
   echo "  version-tag    The Nim version to install (e.g., 2.0.14, 2.2.0)"
   echo ""
   echo "Examples:"
   echo "  $0 2.0.14     Install Nim version 2.0.14"
   echo "  $0 installed   List installed versions"
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

# Function to create symlinks for Nim binaries
create_symlinks() {
   local bin_dir="$1"
   local nimble_dir="$HOME/.nimble/bin"

   # Create .nimble/bin if it doesn't exist
   mkdir -p "$nimble_dir"

   # List of binaries to symlink
   local binaries=("nim" "nim-gdb" "nimble" "nimgrep" "nimpretty" "nimsuggest" "testament")

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

# Function to validate version format
validate_version() {
   local version=$1
   if ! [[ $version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
       echo "Error: Invalid version format '$version'"
       echo "Version must be in format 'X.Y.Z' or 'X.Y' where X, Y, and Z are numbers"
       echo "Examples: 2.0.14, 2.2.0, 1.6"
       cd "$INITIAL_DIR"
       exit 1
   fi
}

# Show help if requested or if no parameters
if [ "$1" = "--help" ] || [ $# -eq 0 ]; then
   show_help
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
# Handle version command
elif [ "$1" = "--version" ]; then
   echo "$VERSION"
   cd "$INITIAL_DIR"
   exit 0
# Validate version format for installation
elif [[ $1 =~ ^[0-9] ]]; then
   validate_version "$1"
   VERSION_TAG="v$1"
else
   echo "Error: Invalid command or version format '$1'"
   echo "Use --help for usage information"
   cd "$INITIAL_DIR"
   exit 1
fi

# Set up directory paths
NIMV_DIR="$HOME/.nimv/$1"
NIM_DIR="$NIMV_DIR/Nim"
NIM_BIN_PATH="$NIM_DIR/bin"

# Check if this version is already installed and working
if [ -f "$NIM_BIN_PATH/nim" ] && [ -x "$NIM_BIN_PATH/nim" ]; then
   echo "Nim version $1 is already installed at $NIM_BIN_PATH"
   echo "Setting version $1 as current version..."
   create_symlinks "$NIM_BIN_PATH"
   echo "Done."
   cd "$INITIAL_DIR"
   exit 0
fi

# If we get here, we need to install the version
echo "Installing Nim version $1..."

# Create version-specific directory if it doesn't exist
if [ ! -d "$NIMV_DIR" ]; then
   mkdir -p "$NIMV_DIR"
fi

# Change to the directory and clone/build Nim
cd "$NIMV_DIR" || exit 1
if [ ! -d "Nim" ]; then
   git clone https://github.com/nim-lang/Nim
fi
cd Nim || exit 1

# Fetch all tags and checkout the specified version
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

# Create symlinks to the newly built Nim
if [ -d "$NIM_BIN_PATH" ]; then
   echo "Setting version $1 as current version..."
   create_symlinks "$NIM_BIN_PATH"
   echo "Done."
else
   echo "Error: Nim binary not found at $NIM_BIN_PATH"
   cd "$INITIAL_DIR"
   exit 1
fi

cd "$INITIAL_DIR"