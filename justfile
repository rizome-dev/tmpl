# justfile for github.com/rizome-dev/tmpl
# https://just.systems/

# Set shell for Windows compatibility
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# Default recipe to display help
default:
    @just --list

# Go version and Docker image
go_version := "1.23.4"
docker_image := "golang:" + go_version + "-bullseye"
build_dir := "./build"
sharedlib_source := "./sharedlib/sharedlib.go"

# Colors for output
bold := '\033[1m'
green := '\033[32m'
yellow := '\033[33m'
red := '\033[31m'
reset := '\033[0m'

# Clean build artifacts
clean:
    @echo "{{yellow}}Cleaning build artifacts...{{reset}}"
    rm -rf {{build_dir}}
    rm -rf vendor/
    @echo "{{green}}✓ Clean complete{{reset}}"

# Vendor dependencies
vendor:
    @echo "{{yellow}}Vendoring dependencies...{{reset}}"
    go mod download
    go mod vendor
    go mod tidy
    @echo "{{green}}✓ Vendor complete{{reset}}"

# Create build directory
_create-build-dir:
    @mkdir -p {{build_dir}}

# Build shared library for Darwin/macOS (local)
build-darwin-local: vendor _create-build-dir
    @echo "{{yellow}}Building shared library for Darwin (macOS)...{{reset}}"
    @if [ ! -f {{sharedlib_source}} ]; then \
        echo "{{red}}Error: {{sharedlib_source}} not found{{reset}}"; \
        exit 1; \
    fi
    CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build \
        -buildmode=c-shared \
        -trimpath \
        -ldflags="-s -w" \
        -o {{build_dir}}/signer-arm64.dylib \
        {{sharedlib_source}}
    @echo "{{green}}✓ Built {{build_dir}}/signer-arm64.dylib{{reset}}"

# Build shared library for Linux (local)
build-linux-local: vendor _create-build-dir
    @echo "{{yellow}}Building shared library for Linux (local)...{{reset}}"
    @if [ ! -f {{sharedlib_source}} ]; then \
        echo "{{red}}Error: {{sharedlib_source}} not found{{reset}}"; \
        exit 1; \
    fi
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
        -buildmode=c-shared \
        -trimpath \
        -ldflags="-s -w" \
        -o {{build_dir}}/signer-amd64.so \
        {{sharedlib_source}}
    @echo "{{green}}✓ Built {{build_dir}}/signer-amd64.so{{reset}}"

# Build shared library for Linux using Docker (ensures compatibility)
build-linux-docker: vendor _create-build-dir
    @echo "{{yellow}}Building shared library for Linux (Docker)...{{reset}}"
    @if [ ! -f {{sharedlib_source}} ]; then \
        echo "{{red}}Error: {{sharedlib_source}} not found{{reset}}"; \
        exit 1; \
    fi
    docker run --rm \
        --platform linux/amd64 \
        -v $(pwd):/workspace \
        -w /workspace \
        {{docker_image}} \
        bash -c "CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -buildmode=c-shared -trimpath -ldflags='-s -w' -o {{build_dir}}/signer-amd64.so {{sharedlib_source}}"
    @echo "{{green}}✓ Built {{build_dir}}/signer-amd64.so (via Docker){{reset}}"

# Build all targets
build-all: build-darwin-local build-linux-docker
    @echo "{{green}}✓ All builds complete{{reset}}"
    @ls -la {{build_dir}}/

# Verify shared library dependencies (macOS)
verify-darwin:
    @echo "{{yellow}}Verifying Darwin shared library...{{reset}}"
    @if [ -f {{build_dir}}/signer-arm64.dylib ]; then \
        otool -L {{build_dir}}/signer-arm64.dylib; \
        echo "{{green}}✓ Library verification complete{{reset}}"; \
    else \
        echo "{{red}}Error: {{build_dir}}/signer-arm64.dylib not found{{reset}}"; \
        exit 1; \
    fi

# Verify shared library dependencies (Linux)
verify-linux:
    @echo "{{yellow}}Verifying Linux shared library...{{reset}}"
    @if [ -f {{build_dir}}/signer-amd64.so ]; then \
        if command -v ldd >/dev/null 2>&1; then \
            ldd {{build_dir}}/signer-amd64.so || true; \
        else \
            echo "ldd not available on this system"; \
        fi; \
        echo "{{green}}✓ Library verification complete{{reset}}"; \
    else \
        echo "{{red}}Error: {{build_dir}}/signer-amd64.so not found{{reset}}"; \
        exit 1; \
    fi

# Run tests
test:
    @echo "{{yellow}}Running tests...{{reset}}"
    go test -v -race ./...
    @echo "{{green}}✓ Tests complete{{reset}}"

# Run linter
lint:
    @echo "{{yellow}}Running linter...{{reset}}"
    @if command -v golangci-lint >/dev/null 2>&1; then \
        golangci-lint run ./...; \
    else \
        echo "{{red}}golangci-lint not installed{{reset}}"; \
        echo "Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"; \
        exit 1; \
    fi
    @echo "{{green}}✓ Lint complete{{reset}}"

# Format code
fmt:
    @echo "{{yellow}}Formatting code...{{reset}}"
    go fmt ./...
    @if command -v goimports >/dev/null 2>&1; then \
        goimports -w .; \
    fi
    @echo "{{green}}✓ Format complete{{reset}}"

# Check if Docker is available
check-docker:
    @if ! command -v docker >/dev/null 2>&1; then \
        echo "{{red}}Error: Docker is not installed or not in PATH{{reset}}"; \
        exit 1; \
    fi
    @if ! docker info >/dev/null 2>&1; then \
        echo "{{red}}Error: Docker daemon is not running{{reset}}"; \
        exit 1; \
    fi
    @echo "{{green}}✓ Docker is available{{reset}}"

# Development setup
setup:
    @echo "{{yellow}}Setting up development environment...{{reset}}"
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    go install golang.org/x/tools/cmd/goimports@latest
    go mod download
    @echo "{{green}}✓ Setup complete{{reset}}"

# Show build information
info:
    @echo "{{bold}}Build Information:{{reset}}"
    @echo "  Go Version:     {{go_version}}"
    @echo "  Docker Image:   {{docker_image}}"
    @echo "  Build Dir:      {{build_dir}}"
    @echo "  Source:         {{sharedlib_source}}"
    @echo ""
    @echo "{{bold}}System Information:{{reset}}"
    @echo "  OS:             $(uname -s)"
    @echo "  Arch:           $(uname -m)"
    @echo "  Go:             $(go version)"

# CI/CD pipeline (runs all checks)
ci: vendor lint test
    @echo "{{green}}✓ CI checks passed{{reset}}"

# Quick build for current platform
build:
    @if [ "$(uname -s)" = "Darwin" ]; then \
        just build-darwin-local; \
    else \
        just build-linux-local; \
    fi

# Interactive shell in Docker build environment
shell: check-docker
    docker run --rm -it \
        --platform linux/amd64 \
        -v $(pwd):/workspace \
        -w /workspace \
        {{docker_image}} \
        bash

# Generate header file from shared library
generate-header:
    @echo "{{yellow}}Generating C header files...{{reset}}"
    @if [ -f {{build_dir}}/signer-arm64.h ]; then \
        echo "{{green}}✓ Header file already exists: {{build_dir}}/signer-arm64.h{{reset}}"; \
    else \
        echo "{{yellow}}Header file will be generated during build{{reset}}"; \
    fi

# Bootstrap the current project from this template
bootstrap module_name='' type='cli' *args='':
    #!/bin/bash
    set -euo pipefail
    
    # Colors
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
    
    # Get project name from current directory
    PROJECT_NAME=$(basename "$(pwd)")
    
    # Set module name from parameter or derive from directory
    if [ -z "{{module_name}}" ]; then
        MODULE_NAME="github.com/$(git config user.name 2>/dev/null || echo 'user')/${PROJECT_NAME}"
    else
        MODULE_NAME="{{module_name}}"
    fi
    
    echo -e "${BOLD}Bootstrapping project: ${PROJECT_NAME}${NC}"
    echo -e "Module: ${MODULE_NAME}"
    echo -e "Type: {{type}}"
    echo
    
    # Validate project type
    case "{{type}}" in
        cli|library|sharedlib|api)
            ;;
        *)
            echo -e "${YELLOW}Invalid project type. Use: cli, library, sharedlib, or api${NC}"
            exit 1
            ;;
    esac
    
    # Create minimal directory structure
    echo -e "${BLUE}Creating project structure...${NC}"
    mkdir -p cmd pkg internal docs
    
    # Initialize go module if it doesn't exist
    echo -e "${BLUE}Initializing Go module...${NC}"
    if [ -f "go.mod" ]; then
        echo -e "${YELLOW}go.mod already exists, skipping initialization${NC}"
    else
        go mod init "${MODULE_NAME}"
    fi
    
    # Update imports in Go files if any exist
    if find . -name "*.go" -type f | grep -q .; then
        find . -type f -name "*.go" -exec sed -i.bak "s|github.com/rizome-dev/tmpl|${MODULE_NAME}|g" {} \; && find . -name "*.bak" -delete
    fi
    
    # Update Makefile if it exists
    if [ -f "Makefile" ]; then
        sed -i.bak "s|BINARY_NAME=tmpl|BINARY_NAME=${PROJECT_NAME}|g" Makefile && rm Makefile.bak
    fi
    
    # Create type-specific structure
    case "{{type}}" in
        cli)
            echo -e "${BLUE}Setting up CLI project structure...${NC}"
            mkdir -p "cmd/${PROJECT_NAME}"
            if [ -f "cmd/example/main.go" ]; then
                mv "cmd/example/main.go" "cmd/${PROJECT_NAME}/main.go"
            else
                # Create minimal CLI main file
                echo 'package main' > "cmd/${PROJECT_NAME}/main.go"
                echo '' >> "cmd/${PROJECT_NAME}/main.go"
                echo 'import (' >> "cmd/${PROJECT_NAME}/main.go"
                echo '    "fmt"' >> "cmd/${PROJECT_NAME}/main.go"
                echo '    "os"' >> "cmd/${PROJECT_NAME}/main.go"
                echo ')' >> "cmd/${PROJECT_NAME}/main.go"
                echo '' >> "cmd/${PROJECT_NAME}/main.go"
                echo 'func main() {' >> "cmd/${PROJECT_NAME}/main.go"
                printf '    fmt.Println("Hello from %s")\n' "${PROJECT_NAME}" >> "cmd/${PROJECT_NAME}/main.go"
                echo '    os.Exit(0)' >> "cmd/${PROJECT_NAME}/main.go"
                echo '}' >> "cmd/${PROJECT_NAME}/main.go"
            fi
            rm -rf "cmd/example"
            ;;
        library)
            echo -e "${BLUE}Setting up library project structure...${NC}"
            mkdir -p "pkg/${PROJECT_NAME}"
            # Create minimal library file
            echo "package ${PROJECT_NAME}" > "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            echo "" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            echo "// Version returns the library version" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            echo "func Version() string {" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            echo '    return "0.1.0"' >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            echo "}" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}.go"
            # Create minimal test file
            echo "package ${PROJECT_NAME}" > "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo "" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo 'import "testing"' >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo "" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo "func TestVersion(t *testing.T) {" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo '    if v := Version(); v == "" {' >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo '        t.Error("Version() returned empty string")' >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo "    }" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            echo "}" >> "pkg/${PROJECT_NAME}/${PROJECT_NAME}_test.go"
            rm -rf "cmd/example" "pkg/example"
            ;;
        api)
            echo -e "${BLUE}Setting up API project structure...${NC}"
            mkdir -p "cmd/${PROJECT_NAME}"
            # Create API server file using printf to avoid just parser issues
            printf '%s\n' 'package main' > "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' 'import (' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "context"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "fmt"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "log"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "net/http"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "os"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "os/signal"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "syscall"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    "time"' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' ')' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' 'func main() {' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    ctx, cancel := context.WithCancel(context.Background())' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    defer cancel()' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    sigChan := make(chan os.Signal, 1)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    mux := http.NewServeMux()' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        w.Header().Set("Content-Type", "application/json")' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        w.WriteHeader(http.StatusOK)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        fmt.Fprint(w, `{"status":"ok"}`)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    })' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    srv := &http.Server{' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        Addr:         ":8080",' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        Handler:      mux,' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        ReadTimeout:  10 * time.Second,' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        WriteTimeout: 10 * time.Second,' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        IdleTimeout:  60 * time.Second,' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    }' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    go func() {' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        log.Printf("Starting server on %s", srv.Addr)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '            log.Fatalf("Failed to start server: %v", err)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        }' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    }()' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    <-sigChan' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    log.Println("Shutting down server...")' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    shutdownCtx, shutdownCancel := context.WithTimeout(ctx, 30*time.Second)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    defer shutdownCancel()' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    if err := srv.Shutdown(shutdownCtx); err != nil {' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '        log.Printf("Server shutdown error: %v", err)' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    }' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '    log.Println("Server stopped")' >> "cmd/${PROJECT_NAME}/main.go"
            printf '%s\n' '}' >> "cmd/${PROJECT_NAME}/main.go"
            rm -rf "cmd/example"
            ;;
        sharedlib)
            echo -e "${BLUE}Setting up shared library project structure...${NC}"
            # sharedlib already exists in template, just clean up
            rm -rf "cmd/example" "pkg/example"
            ;;
    esac
    
    # Clean up any remaining example directories
    find . -type d -name "example" -exec rm -rf {} + 2>/dev/null || true
    
    echo
    echo -e "${GREEN}✓ Project '${PROJECT_NAME}' bootstrapped successfully!${NC}"
    echo
    echo "Next steps:"
    echo "  make setup    # Install development tools"
    echo "  make test     # Run tests"
    echo "  make build    # Build the project"

# Show bootstrap help
bootstrap-help:
    @echo "{{bold}}Bootstrap Usage:{{reset}}"
    @echo ""
    @echo "  just bootstrap [module-name] [type]"
    @echo ""
    @echo "{{bold}}Arguments:{{reset}}"
    @echo "  module-name     Go module name (default: github.com/<git-user>/<current-dir>)"
    @echo "  type            Project type: cli, library, sharedlib, api (default: cli)"
    @echo ""
    @echo "{{bold}}Notes:{{reset}}"
    @echo "  - Bootstraps the current directory (must be run from project root)"
    @echo "  - Creates go.mod and basic project structure based on type"
    @echo "  - Updates imports from template to your module name"
    @echo ""
    @echo "{{bold}}Examples:{{reset}}"
    @echo "  just bootstrap                           # Uses defaults"
    @echo "  just bootstrap github.com/user/myapp     # Custom module, default type (cli)"
    @echo "  just bootstrap github.com/org/mylib library  # Custom module and type"