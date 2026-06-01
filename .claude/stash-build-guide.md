# Stash Build Guide

Reference for building [stashapp/stash](https://github.com/stashapp/stash) from source — especially our fork with custom UI changes.

## How It Works

Stash is a Go backend + React frontend monolith. The build produces a **single binary** (`stash.exe` on Windows). Here's how the pieces fit together:

1. **Frontend** (React/Vite) lives in `ui/v2.5/`. It uses GraphQL to talk to the backend. Before it can build, GraphQL types must be code-generated from the schema.
2. **Backend** (Go) lives in `cmd/stash/`, `internal/`, `pkg/`. It also needs GraphQL code generation for its resolvers.
3. **Embedding**: Go's `//go:embed` directive (in `ui/ui.go`) bakes the built frontend files (`ui/v2.5/build/`) directly into the Go binary. The result is one self-contained executable — no separate web server, no static files to deploy.

```
Frontend Pipeline                 Backend Pipeline
-----------------                 -----------------
pnpm install                      go generate ./cmd/stash
       |                            (gqlgen -> GraphQL resolvers)
GraphQL codegen                   go generate ./ui
  (generate-ui: gql-gen)            (generate-login-locale)
       |                                   |
vite build                                 |
  -> ui/v2.5/build/                        |
       |                                   |
       +-------------- merge -------------+
                         |
                go build ./cmd/stash
                (embeds ui/v2.5/build/ via go:embed)
                         |
                   Single binary
```

### Key Files

| File | Purpose |
|---|---|
| `Makefile` | All build targets, cross-compilation, dev commands |
| `go.mod` | Go version (1.25.0) and dependencies |
| `cmd/stash/main.go` | Binary entry point, `//go:generate` for gqlgen |
| `ui/ui.go` | `//go:embed` directives for frontend + login UI |
| `ui/v2.5/package.json` | Frontend deps, scripts, Node/pnpm version constraints |
| `ui/v2.5/vite.config.js` | Vite configuration — output to `build/`, gzip compression |
| `internal/api/server.go` | Serves embedded UI, CSP headers, plugin routes |

## Prerequisites

| Tool | Version | Why |
|---|---|---|
| **Go** | 1.25+ | Backend compiler. Version declared in `go.mod` |
| **Node.js** | >= 20 | Frontend toolchain. Declared in `ui/v2.5/package.json` `"engines"` |
| **pnpm** | 10.33.0 | Package manager. Declared in `package.json` `"packageManager"`. Ships via corepack |
| **GCC / MinGW64** | any | Required — `CGO_ENABLED=1` is hardcoded in the Makefile (SQLite needs CGO) |
| **GNU Make** | any | Build orchestration. Windows: `mingw32-make` (bundled with MinGW) |
| **ffmpeg** | any | Runtime dependency only — not needed at build time |

## Windows Setup

### Option A: Automated via Batch Script

Run `.claude/setup-toolchain.bat` as Administrator (see below). It installs everything via winget and chocolatey.

### Option B: Manual

1. **Go**: `winget install GoLang.Go` — installs to `C:\Program Files\Go`, adds to PATH
2. **Node.js** (if not installed): `winget install OpenJS.NodeJS.LTS` — installs to `C:\Program Files\nodejs`
3. **MinGW64**: `choco install mingw` — installs GCC, g++, and `mingw32-make`. The **x86_64-posix-seh** variant is what you want
4. **pnpm**: `corepack enable` — activates pnpm via Node.js corepack (no separate install)

After installation, **restart your terminal** so PATH changes take effect.

### Verify

```cmd
go version          &:: should show go1.25.x
node --version      &:: should show v20+ or v24+
pnpm --version      &:: should show 10.33.0
gcc --version       &:: should show x86_64-posix-seh
mingw32-make --version
```

## Build Commands

All commands use `mingw32-make` on Windows instead of `make`.

### Full Build (produces stash.exe)

```cmd
mingw32-make pre-ui          &:: pnpm install
mingw32-make generate        &:: GraphQL codegen (frontend + backend)
mingw32-make ui              &:: Vite production build -> ui/v2.5/build/
mingw32-make build           &:: Go binary with embedded UI
```

Or as a one-liner: `mingw32-make release` (runs all of the above).

### Release Build

```cmd
mingw32-make build-release   &:: strips debug symbols, enables PIE, trimpath
```

### Individual Targets

| Target | What it does |
|---|---|
| `mingw32-make pre-ui` | `pnpm install --frozen-lockfile` |
| `mingw32-make generate-ui` | `npm run gqlgen` — frontend GraphQL typed hooks |
| `mingw32-make generate-backend` | `go generate ./cmd/stash` — Go GraphQL resolvers |
| `mingw32-make generate` | Both of the above |
| `mingw32-make generate-login-locale` | `go generate ./ui` — login page locale files |
| `mingw32-make ui-only` | `vite build` -> `ui/v2.5/build/` |
| `mingw32-make ui` | `pre-ui` -> `generate` -> `ui-only` -> `generate-login-locale` |
| `mingw32-make stash` | `go build ./cmd/stash` |
| `mingw32-make build` | Dynamic debug build |
| `mingw32-make build-release` | Release build (stripped, PIE) |
| `mingw32-make touch-ui` | Creates placeholder `ui/v2.5/build/index.html` so `go:embed` doesn't fail without a frontend build |

### Build Flags

The Makefile injects via `-ldflags`:
- Build timestamp
- Git hash (`git rev-parse --short HEAD`)
- Version string (`git describe --tags`)
- Official build flag (false for fork builds)

SQLite build tags: `sqlite_stat4 sqlite_math_functions` (always set).

## Development Mode (Hot-Reload)

For frontend-only changes — no binary rebuild needed during iteration. The Vite dev server proxies API calls to the Go backend and provides hot module replacement (HMR) — save a file, browser updates instantly.

### Terminal 1: Go Backend

```cmd
mingw32-make pre-ui
mingw32-make generate
mingw32-make server-start    &:: runs go run ./cmd/stash on :9999
```

### Terminal 2: Vite Dev Server

```cmd
mingw32-make ui-start        &:: runs vite dev server on :3000, proxies API to :9999
```

Access at `http://localhost:3000/`. Edit any file under `ui/v2.5/src/`, save, browser auto-refreshes.

### Dev Mode Caveats

- **No authentication.** Cross-origin session cookies between `:3000` (Vite) and `:9999` (Go) don't work. Disable auth in the Stash settings during frontend development.
- The backend URL defaults to `http://localhost:9999` and can be overridden with the environment variable `VITE_APP_PLATFORM_URL`.

## Producing a Custom Binary

When the change is done and tested in dev mode:

```cmd
mingw32-make ui          &:: rebuild frontend -> ui/v2.5/build/
mingw32-make build       &:: compile Go binary with embedded UI
```

The resulting `stash.exe` can replace the existing Stash binary. Copy it to where your Stash installation lives and restart.

## Batch Scripts

The `.claude/` directory contains batch scripts that automate the common workflows. They are meant to be run from the repo root (`D:\Dev\Stash\stash\`).

### setup-toolchain.bat

Installs all build prerequisites. **Run as Administrator** (winget and choco need elevated permissions).

What it does:
1. Installs Go via winget
2. Installs MinGW64 (GCC + mingw32-make) via chocolatey
3. Activates pnpm via corepack
4. Verifies all tools are on PATH

### build.bat

Full build from clean state to `stash.exe`. Run from the repo root.

What it does:
1. Runs `mingw32-make pre-ui` (pnpm install)
2. Runs `mingw32-make generate` (GraphQL codegen)
3. Runs `mingw32-make ui` (Vite build)
4. Runs `mingw32-make build` (Go compile with embedded frontend)
5. Reports the path to the resulting binary

### dev.bat

Starts the development environment (two processes). Run from the repo root.

What it does:
1. Runs `mingw32-make pre-ui` and `mingw32-make generate` (one-time setup)
2. Starts the Go backend (`mingw32-make server-start`) in a new terminal window
3. Starts the Vite dev server (`mingw32-make ui-start`) in the current terminal
4. Ctrl+C stops both

## Cross-Compilation

Uses Docker with a pre-built compiler image (contains all cross-compilers). Node.js is NOT in the image — build the UI locally first.

```cmd
:: Step 1: Build UI locally
mingw32-make pre-ui
mingw32-make generate
mingw32-make ui

:: Step 2: Cross-compile in Docker
docker pull ghcr.io/stashapp/compiler
docker run --rm --mount type=bind,source="%cd%",target=/stash -w /stash -it ghcr.io/stashapp/compiler /bin/bash

:: Inside container:
make build-cc-windows         &:: -> dist/stash-win.exe
make build-cc-linux           &:: -> dist/stash-linux
make build-cc-linux-arm64v8   &:: -> dist/stash-linux-arm64v8
make build-cc-macos           &:: -> dist/stash-macos (universal binary)
make build-cc-all             &:: all platforms
```

## Docker Build

Multi-stage build that produces a runnable image:

```cmd
mingw32-make docker-build
```

Stage 1 (`node:24-alpine`): builds frontend. Stage 2 (`golang:1.25.9-alpine`): builds backend, embeds frontend. Stage 3 (`alpine:latest`): runtime image with `vips-tools` and `ffmpeg`.

## Testing

| Command | What |
|---|---|
| `mingw32-make test` | Unit tests (`go test ./...`) |
| `mingw32-make it` | Unit + integration tests (`-tags integration`) |
| `mingw32-make validate` | Full validation: `validate-ui` + `validate-backend` |
| `mingw32-make validate-ui` | Frontend: lint + typecheck + format-check |
| `mingw32-make validate-backend` | Backend: golangci-lint + integration tests |
| `mingw32-make lint` | Go linting only |
| `mingw32-make fmt` | Go formatting |

## Common Gotchas

1. **CGO is mandatory.** `CGO_ENABLED=1` is hardcoded in the Makefile. You need a C compiler (GCC via MinGW). No way around it.

2. **`touch-ui` prevents embed failures.** If you run `go build ./cmd/stash` without ever building the frontend, it fails because `//go:embed v2.5/build` needs the directory to exist. The Makefile handles this automatically. If building manually without Make, create `ui/v2.5/build/index.html` yourself.

3. **pnpm, not npm/yarn.** The project uses pnpm. `corepack enable` activates it. Using npm or yarn will fail or produce wrong lockfiles.

4. **GraphQL codegen must run first.** Both `generate-ui` (frontend typed queries) and `generate-backend` (Go resolvers) must run before their respective builds. Skipping this causes missing-type compilation errors.

5. **Go version must match `go.mod`.** Currently 1.25.0. Using an older Go version will fail with a version mismatch error.

6. **SQLite build tags.** If building manually (without Make), you must include `-tags "sqlite_stat4 sqlite_math_functions"` or queries behave differently.

7. **Docker cross-compile: UI must be pre-built.** The compiler Docker image has no Node.js. Always build the frontend locally first, then cross-compile the Go binary inside Docker.

8. **Windows: use `mingw32-make`, not `make`.** The `make` command is not available on Windows unless you install MSYS2. MinGW ships `mingw32-make` which works identically.

9. **Restart terminal after installing tools.** winget and choco modify PATH, but the current terminal doesn't pick up the change until restarted.

## CI Pipeline (for reference)

1. **Generate** (Ubuntu 24.04): `pre-ui` -> `generate` -> `validate-ui` -> `ui` -> upload artifacts
2. **Test**: downloads artifacts -> `make it`
3. **Build** (7-platform matrix): downloads UI artifacts -> `make build-cc-{platform}` in Docker
4. **Release**: collects binaries -> SHA1 checksums -> GitHub release
