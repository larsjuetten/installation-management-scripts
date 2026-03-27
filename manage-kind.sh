#!/bin/bash

# kind installation script with version management
# Installs kind from GitHub releases and manages multiple versions

set -e

INSTALL_DIR="${HOME}/.local/bin"
KIND_BASE_DIR="${HOME}/.local/share/kind"
SYMLINK_PATH="${INSTALL_DIR}/kind"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Detect OS and architecture
detect_platform() {
    local os=""
    local arch=""
    
    case "$(uname -s)" in
        Linux*)     os="linux" ;;
        Darwin*)    os="darwin" ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
    
    case "$(uname -m)" in
        x86_64)     arch="amd64" ;;
        aarch64)    arch="arm64" ;;
        arm64)      arch="arm64" ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    echo "${os}-${arch}"
}

# Fetch available versions from GitHub
fetch_versions() {
    print_info "Fetching available versions from GitHub..."
    curl -s "https://api.github.com/repos/kubernetes-sigs/kind/releases" | \
        grep '"tag_name":' | \
        sed -E 's/.*"v([^"]+)".*/\1/' | \
        head -20
}

# Install a specific version
install_version() {
    local version="$1"
    local platform
    platform=$(detect_platform)
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local download_url="https://github.com/kubernetes-sigs/kind/releases/download/v${version}/kind-${platform}"
    local version_dir="${KIND_BASE_DIR}/v${version}"
    local binary_path="${version_dir}/kind"
    
    # Check if version already installed
    if [ -f "${binary_path}" ]; then
        print_info "Version v${version} is already installed"
        return 0
    fi
    
    print_info "Installing kind v${version}..."
    
    # Create directories
    mkdir -p "${version_dir}"
    mkdir -p "${INSTALL_DIR}"
    
    # Download binary
    print_info "Downloading from ${download_url}..."
    if ! curl -L -o "${binary_path}" "${download_url}"; then
        print_error "Failed to download kind v${version}"
        rm -f "${binary_path}"
        return 1
    fi
    
    # Make executable
    chmod +x "${binary_path}"
    
    # Verify binary
    if ! "${binary_path}" version &>/dev/null; then
        print_error "Downloaded binary is not valid"
        rm -f "${binary_path}"
        return 1
    fi
    
    print_success "Installed kind v${version} to ${version_dir}"
    
    # Set as active if no symlink exists
    if [ ! -L "${SYMLINK_PATH}" ]; then
        switch_version "${version}"
    fi
}

# Switch to a different version
switch_version() {
    local version="$1"
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local version_dir="${KIND_BASE_DIR}/v${version}"
    local binary_path="${version_dir}/kind"
    
    if [ ! -f "${binary_path}" ]; then
        print_error "Version v${version} is not installed"
        print_info "Available versions:"
        list_installed_versions
        return 1
    fi
    
    # Create or update symlink
    rm -f "${SYMLINK_PATH}"
    ln -s "${binary_path}" "${SYMLINK_PATH}"
    
    print_success "Switched to kind v${version}"
    print_info "Active version: $(${SYMLINK_PATH} version)"
}

# List installed versions
list_installed_versions() {
    if [ ! -d "${KIND_BASE_DIR}" ]; then
        print_info "No versions installed"
        return 0
    fi
    
    local active_version=""
    if [ -L "${SYMLINK_PATH}" ]; then
        local target
        target=$(readlink "${SYMLINK_PATH}")
        active_version=$(basename "$(dirname "${target}")")
    fi
    
    echo "Installed versions:"
    for version_dir in "${KIND_BASE_DIR}"/v*; do
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
    
    # Remove 'v' prefix if present
    version="${version#v}"
    
    local version_dir="${KIND_BASE_DIR}/v${version}"
    local binary_path="${version_dir}/kind"
    
    if [ ! -d "${version_dir}" ]; then
        print_error "Version v${version} is not installed"
        return 1
    fi
    
    # Check if it's the active version
    if [ -L "${SYMLINK_PATH}" ]; then
        local target
        target=$(readlink "${SYMLINK_PATH}")
        if [ "${target}" = "${binary_path}" ]; then
            print_error "Cannot delete active version v${version}"
            print_info "Switch to another version first"
            return 1
        fi
    fi
    
    read -p "Delete kind v${version}? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${version_dir}"
        print_success "Deleted kind v${version}"
    else
        print_info "Cancelled"
    fi
}

# Show current version
show_current() {
    if [ -L "${SYMLINK_PATH}" ]; then
        echo "Active version:"
        "${SYMLINK_PATH}" version
    else
        print_info "No active version set"
    fi
}

# Show usage
usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
    install <version>    Install a specific version (e.g., 0.20.0 or v0.20.0)
    switch <version>     Switch to an installed version
    delete <version>     Delete an installed version
    list                 List all installed versions
    list-available       List available versions from GitHub
    current              Show current active version
    help                 Show this help message

Examples:
    $0 install 0.20.0
    $0 switch 0.19.0
    $0 delete 0.18.0
    $0 list
    $0 list-available

Installation directory: ${INSTALL_DIR}
Versions directory: ${KIND_BASE_DIR}
EOF
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        usage
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "${command}" in
        install)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version"
                print_info "Usage: $0 install <version>"
                exit 1
            fi
            install_version "$1"
            ;;
        switch)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version"
                print_info "Usage: $0 switch <version>"
                exit 1
            fi
            switch_version "$1"
            ;;
        delete)
            if [ $# -eq 0 ]; then
                print_error "Please specify a version"
                print_info "Usage: $0 delete <version>"
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
