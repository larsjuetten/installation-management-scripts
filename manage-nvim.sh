#!/bin/bash
# Neovim Installation Manager Script
# This script downloads, installs and manages Neovim appimage versions

# Default configuration
NVIM_VERSION="v0.11.4"  # Default version
INSTALL_DIR="$HOME/.local/bin"  # Default installation location

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -v|--version)
      NVIM_VERSION="$2"
      shift 2
      ;;
    -d|--directory)
      INSTALL_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -v, --version VERSION    Specify Neovim version to install (default: v0.11.4)"
      echo "  -d, --directory DIR      Specify installation directory (default: \$HOME/.local/bin)"
      echo "  -h, --help               Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Ensure the installation directory exists
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Creating installation directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR" || { echo "Failed to create directory $INSTALL_DIR"; exit 1; }
fi

# Construct the download URL and filename
DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.appimage"
NVIM_FILENAME="nvim-${NVIM_VERSION}-linux-x86_64.appimage"
NVIM_FILEPATH="$INSTALL_DIR/$NVIM_FILENAME"

echo "Downloading Neovim ${NVIM_VERSION} to ${NVIM_FILEPATH}..."

# Download the appimage
curl -L "$DOWNLOAD_URL" -o "$NVIM_FILEPATH" || { echo "Failed to download Neovim"; exit 1; }

# Make the appimage executable
chmod +x "$NVIM_FILEPATH" || { echo "Failed to make appimage executable"; exit 1; }

# Create/update symbolic link
SYMLINK_PATH="$INSTALL_DIR/nvim"
if [ -L "$SYMLINK_PATH" ]; then
  echo "Updating existing symlink to point to $NVIM_FILENAME"
  rm "$SYMLINK_PATH"
elif [ -e "$SYMLINK_PATH" ]; then
  echo "Warning: $SYMLINK_PATH exists but is not a symlink. Renaming to nvim.backup"
  mv "$SYMLINK_PATH" "$SYMLINK_PATH.backup"
fi

ln -s "$NVIM_FILEPATH" "$SYMLINK_PATH" || { echo "Failed to create symlink"; exit 1; }

echo "Neovim $NVIM_VERSION installed successfully!"
echo "You can run it using: $SYMLINK_PATH"

# Verify if the installation directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Warning: $INSTALL_DIR is not in your PATH."
  echo "Consider adding the following to your shell profile:"
  echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
fi