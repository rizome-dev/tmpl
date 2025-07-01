# tmpl

[![GoDoc](https://pkg.go.dev/badge/github.com/rizome-dev/tmpl)](https://pkg.go.dev/github.com/rizome-dev/tmpl)
[![Go Report Card](https://goreportcard.com/badge/github.com/rizome-dev/tmpl)](https://goreportcard.com/report/github.com/rizome-dev/tmpl)
[![CI](https://github.com/rizome-dev/tmpl/actions/workflows/ci.yml/badge.svg)](https://github.com/rizome-dev/tmpl/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

built by: [rizome labs](https://rizome.dev)

contact us: [hi (at) rizome.dev](mailto:hi@rizome.dev)

## Quick Start

### Using Bootstrap with Just

The easiest way to create a new project from this template:

```bash
# Clone the template
git clone https://github.com/rizome-dev/tmpl.git
cd tmpl

# Create a new CLI project
just bootstrap myapp github.com/yourusername/myapp cli --git

# Create a new library project  
just bootstrap mylib github.com/yourusername/mylib library --git

# Create a new API project
just bootstrap myapi github.com/yourusername/myapi api --git --install

# Show bootstrap help
just bootstrap-help
```

### Bootstrap Command

```
just bootstrap <project-name> [module-name] [type] [options]

Arguments:
  project-name    Name of the new project (required)
  module-name     Go module name (default: github.com/user/project)
  type            Project type: cli, library, sharedlib, api (default: library)

Options:
  --git, -g       Initialize git repository
  --install, -i   Install development dependencies
```

### Manual Setup

```bash
# Clone this template
git clone https://github.com/rizome-dev/tmpl.git myproject
cd myproject

# Remove git history
rm -rf .git

# Initialize as your project
go mod edit -module github.com/yourusername/myproject
find . -type f -name "*.go" -exec sed -i '' 's|github.com/rizome-dev/tmpl|github.com/yourusername/myproject|g' {} +

# Initialize git
git init
git add .
git commit -m "Initial commit"
```

## Project Structure

```
.
├── cmd/                    # Main applications
│   └── example/           # Example CLI application
├── pkg/                    # Public library code
│   └── example/           # Example package with tests
├── internal/              # Private application code
│   └── version/           # Version information package
├── sharedlib/             # Shared C library source
├── scripts/               # Build and utility scripts
│   └── e2e-test.sh       # End-to-end test script
├── docs/                  # Documentation
├── .github/               # GitHub specific files
│   └── workflows/         # GitHub Actions workflows
├── Makefile              # Make-based build configuration
├── justfile              # Just-based build configuration (includes bootstrap)
└── go.mod                # Go module definition
```

## Development

### Prerequisites

- Go 1.21 or later
- Make (for Makefile commands)
- just (optional, for justfile commands)
- Docker (optional, for containerized builds)

### Setup Development Environment

```bash
# Install development tools
make setup

# Or using just
just setup
```

### Building

```bash
# Build the project
make build

# Build shared libraries
make sharedlib-all

# Cross-platform builds
make build-cross

# Using just for shared libraries
just build-all
```

### Testing

```bash
# Run tests
make test

# Run tests with coverage
make coverage

# Run benchmarks
make benchmark

# Run e2e tests (requires built shared library)
./scripts/e2e-test.sh
```

### Linting and Formatting

```bash
# Run linter
make lint

# Format code
make fmt

# Run security scan
make security
```

## Shared Library Usage

This template includes support for building Go code as shared C libraries.

### Building Shared Libraries

```bash
# Build for current platform
just build

# Build for macOS
just build-darwin-local

# Build for Linux (using Docker for compatibility)
just build-linux-docker
```

### Using the Shared Library

Example C usage:

```c
#include <stdio.h>
#include <dlfcn.h>

int main() {
    void *handle = dlopen("./build/signer-amd64.so", RTLD_LAZY);
    
    char* (*GetVersion)() = dlsym(handle, "GetVersion");
    printf("Version: %s\n", GetVersion());
    
    dlclose(handle);
    return 0;
}
```

Example Python usage:

```python
import ctypes

lib = ctypes.CDLL('./build/signer-amd64.so')
lib.GetVersion.restype = ctypes.c_char_p

version = lib.GetVersion().decode('utf-8')
print(f"Version: {version}")
```

## CI/CD

The project includes GitHub Actions workflows for:

- **CI Pipeline**: Runs on push and pull requests
  - Linting with golangci-lint
  - Testing on multiple Go versions and platforms
  - Building shared libraries
  - Security scanning
  - E2E tests

- **Release Pipeline**: Runs on version tags
  - Creates GitHub releases
  - Builds artifacts for multiple platforms
  - Generates checksums
  - Creates release archives

### Creating a Release

```bash
# Tag a new version
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## Configuration Files

- `.editorconfig` - Editor configuration for consistent formatting
- `.gitignore` - Git ignore patterns for Go projects
- `.golangci.yml` - Linting rules and configuration
- `CLAUDE.md` - AI assistant instructions (Claude Code)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Built by [rizome labs](https://rizome.dev)

Contact us: [hi@rizome.dev](mailto:hi@rizome.dev)

## Resources

- [Effective Go](https://golang.org/doc/effective_go.html)
- [Go Project Layout](https://github.com/golang-standards/project-layout)
- [Go Code Review Comments](https://github.com/golang/go/wiki/CodeReviewComments)
- [golangci-lint](https://golangci-lint.run/)
- [just](https://just.systems/)
