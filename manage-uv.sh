#!/bin/bash
set -e

# Defaults
VERSION="latest"
INSTALL_PATH="${HOME}/.local/bin"
VERSIONS_BASE="${HOME}/.local/share/uv-installs"
ACTION="install"

# Help function
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  install   Install a version (default)"
    echo "  delete    Delete a version"
    echo "  switch    Switch to a specific version"
    echo "  list      List installed versions"
    echo ""
    echo "Options:"
    echo "  -v, --version <VERSION>  Specify version (default: latest)"
    echo "  -p, --path <PATH>        Specify installation directory (default: ~/.local/bin)"
    echo "  -h, --help               Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        install|delete|switch|list)
            ACTION="$1"
            shift
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -p|--path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ensure versions base exists
mkdir -p "$VERSIONS_BASE"

list_versions() {
    echo "Installed versions in $VERSIONS_BASE:"
    if [ -d "$VERSIONS_BASE" ]; then
        ls -1 "$VERSIONS_BASE"
    else
        echo "No versions installed."
    fi
    
    # Show active version
    if [ -L "${INSTALL_PATH}/uv" ]; then
        CURRENT=$(readlink -f "${INSTALL_PATH}/uv")
        echo ""
        echo "Active version (symlinked in $INSTALL_PATH):"
        basename "$(dirname "$CURRENT")"
    fi
}

switch_version() {
    local TARGET_VERSION="$1"
    if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION="$VERSION"
    fi
    
    if [ "$TARGET_VERSION" == "latest" ]; then
        echo "Error: Cannot switch to 'latest'. Please specify a version number."
        list_versions
        exit 1
    fi

    TARGET_DIR="${VERSIONS_BASE}/${TARGET_VERSION}"
    
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Error: Version $TARGET_VERSION is not installed."
        list_versions
        exit 1
    fi

    echo "Switching active version to $TARGET_VERSION at $INSTALL_PATH"
    mkdir -p "$INSTALL_PATH"
    
    ln -sf "${TARGET_DIR}/uv" "${INSTALL_PATH}/uv"
    ln -sf "${TARGET_DIR}/uvx" "${INSTALL_PATH}/uvx"
    
    echo "Success. uv $TARGET_VERSION is now active."
}

install_version() {
    echo "Requested version: $VERSION"
    
    # If specific version requested and already exists, just switch
    if [ "$VERSION" != "latest" ] && [ -d "${VERSIONS_BASE}/${VERSION}" ]; then
        echo "Version $VERSION already installed."
        switch_version "$VERSION"
        return
    fi

    # Download to temp dir
    TEMP_DIR=$(mktemp -d)
    cleanup() {
        rm -rf "$TEMP_DIR"
    }
    trap cleanup EXIT

    echo "Downloading..."
    export UV_INSTALL_DIR="$TEMP_DIR"
    export UV_NO_MODIFY_PATH=1
    
    INSTALLER_URL="https://astral.sh/uv/install.sh"
    if [ "$VERSION" != "latest" ]; then
        INSTALLER_URL="https://astral.sh/uv/${VERSION}/install.sh"
    fi
    
    curl -LsSf "$INSTALLER_URL" | sh
    
    # Detect version from binary
    DETECTED_VERSION=$("$TEMP_DIR/uv" --version | awk '{print $2}')
    echo "Detected version: $DETECTED_VERSION"
    
    TARGET_DIR="${VERSIONS_BASE}/${DETECTED_VERSION}"
    
    if [ ! -d "$TARGET_DIR" ]; then
        echo "Installing to $TARGET_DIR..."
        mkdir -p "$TARGET_DIR"
        mv "$TEMP_DIR/uv" "$TARGET_DIR/"
        mv "$TEMP_DIR/uvx" "$TARGET_DIR/"
    else
        echo "Version $DETECTED_VERSION is already installed."
    fi
    
    switch_version "$DETECTED_VERSION"
}

delete_version() {
    if [ "$VERSION" == "latest" ]; then
        echo "Error: Please specify a version to delete."
        list_versions
        exit 1
    fi

    TARGET_DIR="${VERSIONS_BASE}/${VERSION}"
    
    if [ -d "$TARGET_DIR" ]; then
        echo "Deleting uv version: $VERSION"
        rm -rf "$TARGET_DIR"
        
        # Check if active version is the one being deleted
        if [ -L "${INSTALL_PATH}/uv" ]; then
            CURRENT_TARGET=$(readlink -f "${INSTALL_PATH}/uv")
            if [[ "$CURRENT_TARGET" == "${TARGET_DIR}"* ]]; then
                echo "Warning: Deleted version was active. Removing symlinks."
                rm -f "${INSTALL_PATH}/uv" "${INSTALL_PATH}/uvx"
            fi
        fi
        echo "Deleted."
    else
        echo "Version $VERSION not found."
    fi
}

# Execute Action
case $ACTION in
    install)
        install_version
        ;;
    switch)
        switch_version
        ;;
    delete)
        delete_version
        ;;
    list)
        list_versions
        ;;
esac
