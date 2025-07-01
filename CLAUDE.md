# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Go template library project (`github.com/rizome-dev/tmpl`) built by rizome labs. The project is in its initial setup phase with standard Go project structure but no implementation yet.

## Build Commands

The project uses `just` for build tasks. Available commands:

```bash
# Build for macOS (local)
just build-darwin-local

# Build for Linux (local)
just build-linux-local

# Build for Linux using Docker (ensures compatibility)
just build-linux-docker

# Bootstrap a new project from this template
just bootstrap myproject github.com/user/myproject cli --git
```

These commands build shared C libraries (.dylib for macOS, .so for Linux) from Go code located at `./sharedlib/sharedlib.go` (file needs to be created).

## Development Setup

1. This is a Go 1.23.4 project
2. Use `go mod vendor` before building (handled by just commands)
3. Build outputs go to `./build/` directory

## Project Structure

Standard Go project layout:
- `cmd/` - Main applications
- `internal/` - Private application and library code  
- `pkg/` - Library code for external use
- `docs/` - Documentation

## Testing

No test framework is currently set up. When implementing tests, use standard Go testing practices with `go test`.

## Important Notes

- The project builds shared C libraries, suggesting interoperability with other languages
- Contact: hi@rizome.dev
- Documentation: https://pkg.go.dev/github.com/rizome-dev/tmpl