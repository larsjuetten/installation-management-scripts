#!/bin/bash
set -e

source "$(dirname "$0")/.env"

# Defaults
VERSION="latest"
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
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Ensure versions base exists
mkdir -p "$VERSIONS_BASE"

list_versions() {
    print_info "Installed versions in $VERSIONS_BASE:"
    if [ -d "$VERSIONS_BASE" ]; then
        ls -1 "$VERSIONS_BASE"
    else
        print_info "No versions installed."
    fi
    
    # Show active version
    if [ -L "${INSTALL_DIR}/uv" ]; then
        CURRENT=$(readlink -f "${INSTALL_DIR}/uv")
        
        print_info "Active version (symlinked in $INSTALL_DIR):"
        basename "$(dirname "$CURRENT")"
    fi
}

switch_version() {
    local TARGET_VERSION="$1"
    if [ -z "$TARGET_VERSION" ]; then
            TARGET_VERSION="$VERSION"
    fi
    
    if [ "$TARGET_VERSION" == "latest" ]; then
        print_error "Cannot switch to 'latest'. Please specify a version number."
        list_versions
        exit 1
    fi

    TARGET_DIR="${VERSIONS_BASE}/${TARGET_VERSION}"
    
    if [ ! -d "$TARGET_DIR" ]; then
        print_error "Version $TARGET_VERSION is not installed."
        list_versions
        exit 1
    fi

    print_info "Switching active version to $TARGET_VERSION at $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    ln -sf "${TARGET_DIR}/uv" "${INSTALL_DIR}/uv"
    ln -sf "${TARGET_DIR}/uvx" "${INSTALL_DIR}/uvx"
    
    print_success "Success. uv $TARGET_VERSION is now active."
}

install_version() {
    print_info "Requested version: $VERSION"
    
    # If specific version requested and already exists, just switch
    if [ "$VERSION" != "latest" ] && [ -d "${VERSIONS_BASE}/${VERSION}" ]; then
        print_info "Version $VERSION already installed."
        switch_version "$VERSION"
        return
    fi

    # Download to temp dir
    TEMP_DIR=$(mktemp -d)
    cleanup() {
        rm -rf "$TEMP_DIR"
    }
    trap cleanup EXIT

    print_info "Downloading..."
    export UV_INSTALL_DIR="$TEMP_DIR"
    export UV_NO_MODIFY_PATH=1
    
    INSTALLER_URL="https://astral.sh/uv/install.sh"
    if [ "$VERSION" != "latest" ]; then
        INSTALLER_URL="https://astral.sh/uv/${VERSION}/install.sh"
    fi
    
    curl -LsSf "$INSTALLER_URL" | sh
    
    # Detect version from binary
    DETECTED_VERSION=$("$TEMP_DIR/uv" --version | awk '{print $2}')
    print_info "Detected version: $DETECTED_VERSION"
    
    TARGET_DIR="${VERSIONS_BASE}/${DETECTED_VERSION}"
    
    if [ ! -d "$TARGET_DIR" ]; then
        print_info "Installing to $TARGET_DIR..."
        mkdir -p "$TARGET_DIR"
        mv "$TEMP_DIR/uv" "$TARGET_DIR/"
        mv "$TEMP_DIR/uvx" "$TARGET_DIR/"
    else
        print_info "Version $DETECTED_VERSION is already installed."
    fi
    
    switch_version "$DETECTED_VERSION"
}

delete_version() {
    if [ "$VERSION" == "latest" ]; then
        print_error "Please specify a version to delete."
        list_versions
        exit 1
    fi

    TARGET_DIR="${VERSIONS_BASE}/${VERSION}"
    
    if [ -d "$TARGET_DIR" ]; then
        print_info "Deleting uv version: $VERSION"
        rm -rf "$TARGET_DIR"
        
        # Check if active version is the one being deleted
        if [ -L "${INSTALL_DIR}/uv" ]; then
            CURRENT_TARGET=$(readlink -f "${INSTALL_DIR}/uv")
            if [[ "$CURRENT_TARGET" == "${TARGET_DIR}"* ]]; then
                print_info "Warning: Deleted version was active. Removing symlinks."
                rm -f "${INSTALL_DIR}/uv" "${INSTALL_DIR}/uvx"
            fi
        fi
        print_success "Deleted."
    else
        print_error "Version $VERSION not found."
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
