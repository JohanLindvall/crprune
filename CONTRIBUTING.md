# Contributing to crprune

You can help with documentation, reproducible bug reports, retention-policy
examples, or code. No Azure subscription, GitHub package, or Kubernetes cluster
is needed to build or test the project.

For usage help, [open a question](https://github.com/JohanLindvall/crprune/issues/new?template=question.yml).
For vulnerabilities, follow [SECURITY.md](SECURITY.md) instead of opening a public
issue. Please follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Set up a checkout

Use Go 1.26 or later (the minimum is declared in [go.mod](go.mod)), Git, GNU Make,
and `jq`. The full script suite expects a Linux environment with standard shell
utilities, including `tar`, `gzip`, and `sha256sum`; Linux or WSL is the simplest
way to match CI. The Go tests themselves use in-memory registries and HTTP test
servers.

Fork the repository for a pull request, clone your fork, and create a branch:

```sh
git clone https://github.com/YOUR-USERNAME/crprune.git
cd crprune
git switch -c improve-quickstart
make build
./crprune --help
make demo
```

`make demo` opens synthetic sample statistics in an interactive terminal. Use
`./crprune top examples/sample-stats.json` for plain output.

## Everyday commands

Run `make help` for the available targets.

| Command | Purpose |
| --- | --- |
| `make build` | Build `./crprune`, with its version derived from Git |
| `make fmt` | Format Go source files |
| `make check` | Check formatting, vet, SPDX headers, Go tests, and script tests |
| `make test-race` | Run Go tests with the race detector, plus script tests |
| `make lint` | Run the pinned golangci-lint, installed into `./bin` on first use |
| `make coverage` | Write race-enabled `coverage.out` and print function coverage |
| `make vuln` | Scan dependencies with govulncheck |
| `make dist-all` | Build Linux amd64/arm64 archives and SHA-256 checksums |

Go downloads dependencies on the first build. `make lint` and `make vuln` can
download their tools too. No test needs cloud credentials or deletes real
packages. For a small change, start with the affected package, for example:

```sh
go test ./internal/rules
```

For code changes, run `make check` before a PR. Also run `make test-race` for
concurrency changes and `make lint` for Go changes. For documentation-only
changes, check the examples and links you edited. CI checks vulnerabilities,
lint, race-enabled coverage, and release builds as well.

## Make a useful contribution

- Fix an unclear instruction, add a focused rule example, or improve a specific
  error message. Browse [good first issues](https://github.com/JohanLindvall/crprune/labels/good%20first%20issue)
  and [help wanted](https://github.com/JohanLindvall/crprune/labels/help%20wanted);
  these lists may be empty.
- Search existing issues before reporting a problem. Include the crprune version,
  registry type, a minimal policy, expected behaviour, and sanitized logs.
- For a new registry backend or a change to deletion semantics, describe the
  use case in an issue before investing in a large implementation.
- Keep a PR focused. Explain the user-visible change, how you checked it, and
  any tradeoffs. Link an existing issue when relevant; an issue is not required
  for a small fix.

Use `gofmt`, follow the surrounding code, and give new Go and shell files
`SPDX-License-Identifier: MIT` headers. Add regression coverage for behaviour
changes, especially retention decisions, incomplete registry responses,
credentials, and cancellation. Update [the reference](docs/reference.md) when
flags or behaviour change; update [the README](README.md) when onboarding changes.
Do not include real credentials or private registry inventories in fixtures.

## Design boundaries

Deletion policy belongs in `internal/pruner`: `Prepare` and `PrepareManifests`
share the same protections, and `DeletionPlan.Execute` revalidates the reviewed
snapshots. Keep registry operations behind `registry.Backend` so safety
regressions can reproduce with `registrytest` or HTTP fixtures.

Literal repository rules and running-image inventories use
`rules.RepositoryMatcher`, which preserves the precedence of earlier regex
rules. Both terminal interfaces share grapheme-aware drawing and wrapping in
`internal/tui`; progress loggers must not write directly to an active terminal.

## Package layout

| Package | Responsibility |
| --- | --- |
| `cmd/crprune` | CLI commands, flags, I/O, credentials, and signals |
| `internal/rules` | Rule parsing, validation, matching, and generation |
| `internal/pruner` | Retention decisions, deletion plans, and statistics |
| `internal/registry` | Registry-neutral manifest access, caching, and deletion |
| `internal/registry/acr` | Azure Container Registry backend |
| `internal/registry/ghcr` | GitHub packages and ghcr.io backend |
| `internal/registry/registrytest` | In-memory registry backend and log recorder |
| `internal/explore` | Interactive statistics, image browsing, and cleanup |
| `internal/progress` | Batch progress tracking, logs, and terminal dashboard |
| `internal/tui` | Shared terminal drawing and lifecycle |
| `internal/imageref` | Image-reference validation |
| `internal/jsonpos` | JSON error locations |
| `internal/fileio` | Atomic file snapshots |
| `rules` | Bundled example retention policies |
| `scripts` | Installer and Kubernetes image inventory, with mocked tests |

## Deeper validation

Fuzz targets exercise rule and manifest parsing, rule matching, image references,
pagination, and Unicode wrapping. Choose one relevant to the change:

```sh
go test ./internal/rules -fuzz=FuzzParseAndCompile -fuzztime=30s
go test ./internal/imageref -fuzz=FuzzSplit -fuzztime=30s
go test ./internal/registry -fuzz=FuzzParseManifest -fuzztime=30s
go test ./internal/registry -fuzz=FuzzNextPage -fuzztime=30s
go test ./internal/rules -fuzz=FuzzRepositoryMatcher -fuzztime=30s
go test ./internal/tui -fuzz=FuzzWrap -fuzztime=30s
```

Add `-parallel=4` to bound CPU use on large machines. Focused benchmarks:

```sh
go test ./internal/pruner -run '^$' -bench BenchmarkCountRunning -benchmem
go test ./internal/registry -run '^$' -bench BenchmarkIndexPlatforms -benchmem
go test ./internal/rules -run '^$' -bench BenchmarkWarningsLiteralInventory -benchmem
go test ./internal/rules -run '^$' -bench BenchmarkRepositoryMatcher -benchmem
go test ./internal/tui -run '^$' -bench BenchmarkWrapLongText -benchmem
```

For terminal visual checks, set `CRPRUNE_RENDER_DIR` to an existing directory and
run `go test ./internal/explore -run TestRenderSample -count=1 -v`. It writes the
terminal's cells, colours, and dimensions as JSON using synthetic sample data.
See [the screenshot instructions](docs/assets/README.md) to refresh the README
preview.

## CI and releases

CI runs on pull requests and pushes. It checks the minimum Go version from
`go.mod` as well as Go 1.27. The main job runs `make check`, vulnerability and lint
checks, race-enabled coverage, and cross-compilation. When changing the pinned
golangci-lint version, update both `Makefile` and `.github/workflows/ci.yml`.

Each build keeps the archives and checksums in a workflow artifact named
`crprune-<commit>`. **Every push to `main` publishes a new patch release.** A PR
build does not publish a release. Release notes group merged PRs by their labels.
