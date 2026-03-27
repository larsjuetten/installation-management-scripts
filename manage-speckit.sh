#!/bin/bash

# speckit installation script with version management
# Installs specify-cli from GitHub releases using uv and manages multiple versions

set -e

source "$(dirname "$0")/.env"

SPECKIT_BASE_DIR="${HOME}/.local/share/speckit"
SYMLINK_PATH="${INSTALL_DIR}/specify-cli"

# Fetch available versions from GitHub
fetch_versions() {
    print_info "Fetching available versions from GitHub releases page..."
    curl -sL "https://github.com/github/spec-kit/releases" | 
        grep -o '/github/spec-kit/releases/tag/[^"]*' | 
        sed 's|/github/spec-kit/releases/tag/||' | 
        sed 's/^v//' | 
        head -20
}

# Install a specific version
install_version() {
    local version="$1"
    version="${version#v}" # remove v prefix

    local version_tag="v${version}"
    local version_dir="${SPECKIT_BASE_DIR}/${version_tag}"
    local tool_dir="${version_dir}/uv-tool"
    local binary_path="${tool_dir}/bin/specify-cli"
    
    # Check if version already installed
    if [ -f "${binary_path}" ]; then
        print_info "Version ${version_tag} is already installed"
        return 0
    fi
    
    print_info "Installing specify-cli ${version_tag}..."
    
    # Create directories
    mkdir -p "${version_dir}"
    
    # Install with uv
    local download_url="git+https://github.com/github/spec-kit.git@${version_tag}"
    print_info "Installing from ${download_url}..."
    
    # We set UV_TOOLS_DIR to control where `uv tool install` places the files.
    if ! UV_TOOLS_DIR="${tool_dir}" uv tool install specify-cli --from "${download_url}"; then
        print_error "Failed to install specify-cli ${version_tag}"
        rm -rf "${version_dir}"
        return 1
    fi
    
    # Make executable (uv should do this, but just in case)
    chmod +x "${binary_path}"

    # Verify binary
    if ! "${binary_path}" --version &>/dev/null; then
        print_error "Installed binary is not valid"
        rm -rf "${version_dir}"
        return 1
    fi
    
    print_success "Installed specify-cli ${version_tag} to ${version_dir}"
    
    # Set as active if no symlink exists
    if [ ! -L "${SYMLINK_PATH}" ]; then
        switch_version "${version}"
    fi
}

# Switch to a different version
switch_version() {
    local version="$1"
    version="${version#v}"
    
    local version_tag="v${version}"
    local version_dir="${SPECKIT_BASE_DIR}/${version_tag}"
    local binary_path="${version_dir}/uv-tool/bin/specify-cli"
    
    if [ ! -f "${binary_path}" ]; then
        print_error "Version ${version_tag} is not installed"
        print_info "To install it, run: $0 install ${version}"
        return 1
    fi
    
    # Create or update symlink
    mkdir -p "${INSTALL_DIR}"
    rm -f "${SYMLINK_PATH}"
    ln -s "${binary_path}" "${SYMLINK_PATH}"
    
    print_success "Switched to specify-cli ${version_tag}"
    print_info "Active version: $(${SYMLINK_PATH} --version)"
}

# List installed versions
list_installed_versions() {
    if [ ! -d "${SPECKIT_BASE_DIR}" ]; then
        print_info "No versions installed"
        return 0
    fi
    
    local active_version=""
    if [ -L "${SYMLINK_PATH}" ]; then
        local target
        target=$(readlink "${SYMLINK_PATH}")
        # Target is .../vX.Y.Z/uv-tool/bin/specify-cli, so we go up 3 levels
        active_version=$(basename "$(dirname "$(dirname "$(dirname "${target}")")")")
    fi
    
    echo "Installed versions:"
    for version_dir in "${SPECKIT_BASE_DIR}"/v*; do
        if [ -d "${version_dir}" ]; then
            local version
            version=$(basename "${version_dir}")
            if [ "${version}" = "${active_version}" ]; then
                echo -e "  ${GREEN}* ${version}${NC} (active)"
            else
                echo "    ${version}"
            fi
        fi
    done
}

# Delete a specific version
delete_version() {
    local version="$1"
    version="${version#v}"

    local version_tag="v${version}"
    local version_dir="${SPECKIT_BASE_DIR}/${version_tag}"
    
    if [ ! -d "${version_dir}" ]; then
        print_error "Version ${version_tag} is not installed"
        return 1
    fi
    
    # Check if it's the active version
    if [ -L "${SYMLINK_PATH}" ]; then
        local target
        target=$(readlink "${SYMLINK_PATH}")
        if [[ "${target}" == "${version_dir}"* ]]; then
            print_error "Cannot delete active version ${version_tag}"
            print_info "Switch to another version first"
            return 1
        fi
    fi
    
    read -p "Delete specify-cli ${version_tag}? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${version_dir}"
        print_success "Deleted specify-cli ${version_tag}"
    else
        print_info "Cancelled"
    fi
}

# Show current version
show_current() {
    if [ -L "${SYMLINK_PATH}" ]; then
        echo "Active version:"
        "${SYMLINK_PATH}" --version
    else
        print_info "No active version set"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Manages installations of specify-cli from github.com/github/spec-kit.
Requires 'uv' to be installed and in the PATH.

Commands:
    install <version>    Install a specific version (e.g., 0.1.0-alpha)
    switch <version>     Switch to an installed version
    delete <version>     Delete an installed version
    list                 List all installed versions
    list-available       List available versions from GitHub (shows top 20)
    current              Show current active version
    help                 Show this help message

Examples:
    $0 install 0.1.0-alpha
    $0 switch 0.1.0-alpha
    $0 delete 0.0.1
    $0 list
    $0 list-available

Installation directory for symlink: ${INSTALL_DIR}
Versions storage directory: ${SPECKIT_BASE_DIR}
EOF
}

# Main script
main() {
    if ! command -v uv &> /dev/null; then
        print_error "'uv' command not found."
        print_info "Please install uv (e.g., run the manage-uv.sh script) and ensure it's in your PATH."
        exit 1
    fi

    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        install)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version to install."
                print_info "Example: $0 install 0.1.0-alpha"
                exit 1
            fi
            install_version "$1"
            ;;
        switch)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version to switch to."
                print_info "Example: $0 switch 0.1.0-alpha"
                exit 1
            fi
            switch_version "$1"
            ;;
        delete)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version to delete."
                print_info "Example: $0 delete 0.0.1"
                exit 1
            fi
            delete_version "$1"
            ;;
        list)
            list_installed_versions
            ;;
        list-available)
            fetch_versions
            ;;
        current)
            show_current
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

main "$@"
