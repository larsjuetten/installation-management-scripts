#!/bin/bash

set -euo pipefail

# Parse command line arguments
FORCE=false
for arg in "$@"; do
    case $arg in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-f|--force] [-h|--help]"
            echo "  -f, --force    Force reinstall even if tools are already installed"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

: ${GO_VERSION:="1.21.3"}
: ${GO_SEC_VERSION:="v2.18.2"}
: ${GOLANGCI_LINT_VERSION:="v1.55.1"}
: ${GO_ENV:=$HOME/.bashrc.d/go.sh}
: ${GO_INSTALLATION_DIR:="$HOME/.local"}



if ! type -p go > /dev/null; then
    echo "Installing Golang $GO_VERSION ..."
    GO_VERSION_FILE=go${GO_VERSION}.linux-amd64.tar.gz
    curl -LOs "https://go.dev/dl/$GO_VERSION_FILE"
    tar -C $GO_INSTALLATION_DIR -xzf $GO_VERSION_FILE
    # rm $GO_VERSION_FILE
fi

cat <<EOF > $GO_ENV

#!/bin/bash
GOPATH=$GO_INSTALLATION_DIR/go/bin
PATH=\$(add_to_system_path \$GOPATH prepend)
GO111MODULE=on

EOF

set -a

. "$GO_ENV"

go install github.com/securego/gosec/v2/cmd/gosec@${GO_SEC_VERSION}
go install github.com/golangci/golangci-lint/cmd/golangci-lint@${GOLANGCI_LINT_VERSION}

# echo "golang version: $(go version)"
# echo "gosec is installed in version: $(gosec --version)"
# echo "$(golangci-lint --version)"

