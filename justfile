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

# Bootstrap a new project from this template
bootstrap project_name module_name='github.com/user/project' type='library' *args='':
    #!/bin/bash
    set -euo pipefail
    
    # Colors
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
    
    echo -e "${BOLD}Bootstrapping new project: {{project_name}}${NC}"
    echo -e "Module: {{module_name}}"
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
    
    # Create project directory
    TARGET_DIR="./{{project_name}}"
    if [ -d "$TARGET_DIR" ]; then
        echo -e "${YELLOW}Directory $TARGET_DIR already exists${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Creating project structure...${NC}"
    mkdir -p "$TARGET_DIR"
    
    # Copy template files
    cp -r cmd pkg internal docs scripts "$TARGET_DIR/" 2>/dev/null || true
    cp .editorconfig .gitignore .golangci.yml Makefile "$TARGET_DIR/"
    
    # Copy justfile for sharedlib projects
    if [ "{{type}}" = "sharedlib" ]; then
        cp justfile "$TARGET_DIR/"
        cp -r sharedlib "$TARGET_DIR/" 2>/dev/null || true
    fi
    
    # Initialize go module
    cd "$TARGET_DIR"
    go mod init "{{module_name}}"
    
    # Update imports in Go files
    find . -type f -name "*.go" -exec sed -i.bak "s|github.com/rizome-dev/tmpl|{{module_name}}|g" {} \; && find . -name "*.bak" -delete
    
    # Update Makefile
    sed -i.bak "s|BINARY_NAME=tmpl|BINARY_NAME={{project_name}}|g" Makefile && rm Makefile.bak
    
    # Create type-specific main file
    case "{{type}}" in
        cli)
            mkdir -p "cmd/{{project_name}}"
            mv "cmd/example/main.go" "cmd/{{project_name}}/main.go" 2>/dev/null || true
            rm -rf "cmd/example"
            ;;
        library)
            mkdir -p "pkg/{{project_name}}"
            if [ -f "pkg/example/example.go" ]; then
                sed "s/example/{{project_name}}/g" "pkg/example/example.go" > "pkg/{{project_name}}/{{project_name}}.go"
                sed "s/example/{{project_name}}/g" "pkg/example/example_test.go" > "pkg/{{project_name}}/{{project_name}}_test.go"
            fi
            rm -rf "pkg/example"
            rm -rf "cmd/example"
            ;;
        api)
            mkdir -p "cmd/{{project_name}}"
            cat > "cmd/{{project_name}}/main.go" << 'EOF'
    package main
    
    import (
        "context"
        "fmt"
        "log"
        "net/http"
        "os"
        "os/signal"
        "syscall"
        "time"
    )
    
    func main() {
        ctx, cancel := context.WithCancel(context.Background())
        defer cancel()
    
        sigChan := make(chan os.Signal, 1)
        signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
    
        mux := http.NewServeMux()
        mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
            fmt.Fprintf(w, "Welcome to {{project_name}} API\n")
        })
        mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
            w.Header().Set("Content-Type", "application/json")
            w.WriteHeader(http.StatusOK)
            fmt.Fprint(w, `{"status":"ok"}`)
        })
    
        srv := &http.Server{
            Addr:         ":8080",
            Handler:      mux,
            ReadTimeout:  10 * time.Second,
            WriteTimeout: 10 * time.Second,
            IdleTimeout:  60 * time.Second,
        }
    
        go func() {
            log.Printf("Starting server on %s", srv.Addr)
            if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
                log.Fatalf("Failed to start server: %v", err)
            }
        }()
    
        <-sigChan
        log.Println("Shutting down server...")
    
        shutdownCtx, shutdownCancel := context.WithTimeout(ctx, 30*time.Second)
        defer shutdownCancel()
    
        if err := srv.Shutdown(shutdownCtx); err != nil {
            log.Printf("Server shutdown error: %v", err)
        }
    
        log.Println("Server stopped")
    }
    EOF
            rm -rf "cmd/example"
            ;;
    esac
    
    # Create basic README
    cat > README.md << EOF
    # {{project_name}}
    
    TODO: Add project description
    
    ## Installation
    
    \`\`\`bash
    go get {{module_name}}
    \`\`\`
    
    ## Usage
    
    TODO: Add usage examples
    
    ## Development
    
    ### Setup
    
    \`\`\`bash
    make setup
    \`\`\`
    
    ### Build
    
    \`\`\`bash
    make build
    \`\`\`
    
    ### Test
    
    \`\`\`bash
    make test
    \`\`\`
    
    ## License
    
    TODO: Add license information
    EOF
    
    # Initialize git if requested
    if [[ " {{args}} " =~ " --git " ]] || [[ " {{args}} " =~ " -g " ]]; then
        git init
        git add .
        git commit -m "Initial commit
    
    Created from github.com/rizome-dev/tmpl template"
        echo -e "${GREEN}✓ Git repository initialized${NC}"
    fi
    
    # Install deps if requested
    if [[ " {{args}} " =~ " --install " ]] || [[ " {{args}} " =~ " -i " ]]; then
        make setup || true
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    fi
    
    echo
    echo -e "${GREEN}✓ Project '{{project_name}}' created successfully!${NC}"
    echo
    echo "Next steps:"
    echo "  cd {{project_name}}"
    echo "  make setup"
    echo "  make test"
    echo "  make build"

# Show bootstrap help
bootstrap-help:
    @echo "{{bold}}Bootstrap Usage:{{reset}}"
    @echo ""
    @echo "  just bootstrap <project-name> [module-name] [type] [options]"
    @echo ""
    @echo "{{bold}}Arguments:{{reset}}"
    @echo "  project-name    Name of the new project (required)"
    @echo "  module-name     Go module name (default: github.com/user/project)"
    @echo "  type            Project type: cli, library, sharedlib, api (default: library)"
    @echo ""
    @echo "{{bold}}Options:{{reset}}"
    @echo "  --git, -g       Initialize git repository"
    @echo "  --install, -i   Install development dependencies"
    @echo ""
    @echo "{{bold}}Examples:{{reset}}"
    @echo "  just bootstrap myapp github.com/user/myapp cli --git"
    @echo "  just bootstrap mylib github.com/company/mylib library"
    @echo "  just bootstrap myapi github.com/org/myapi api --git --install"