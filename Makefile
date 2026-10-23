BINARY  := regtend
PKG     := ./cmd/regtend
DISTDIR := dist

# Version is derived from git and injected into the binary. Override on the
# command line (e.g. `make build VERSION=v1.2.3`) to pin it.
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -s -w -X main.version=$(VERSION)

# OS/ARCH pairs to cross-compile for `dist-all`.
PLATFORMS := linux/amd64 linux/arm64

# Pinned golangci-lint, installed into ./bin under a versioned name so that
# changing the version installs it again instead of using an older binary.
GOLANGCI_LINT_VERSION := v2.15.0
GOLANGCI_LINT         := $(CURDIR)/bin/golangci-lint-$(GOLANGCI_LINT_VERSION)

.PHONY: all help build demo fmt fmt-check check test test-race test-scripts coverage vet license-check lint vuln clean dist-all

all: build

help:
	@printf '%s\n' \
	  'make build          Build ./regtend (default target)' \
	  'make demo           Explore synthetic data; no credentials needed' \
	  'make fmt            Format Go source files' \
	  'make check          Check formatting, vet, licenses, and all tests' \
	  'make test           Run Go and mocked shell tests (requires jq)' \
	  'make test-race      Run Go tests with the race detector and shell tests' \
	  'make coverage       Write coverage.out and print function coverage' \
	  'make vet            Run go vet' \
	  'make license-check  Check SPDX headers in Go and shell source' \
	  'make lint           Run pinned golangci-lint (downloads on first use)' \
	  'make vuln           Scan dependencies with govulncheck' \
	  'make dist-all       Build Linux amd64/arm64 release archives' \
	  'make clean          Remove local binary and release archives'

build:
	go build -trimpath -ldflags '$(LDFLAGS)' -o $(BINARY) $(PKG)

demo: build
	./$(BINARY) explore examples/sample-stats.json

fmt:
	gofmt -w cmd internal rules

fmt-check:
	@set -eu; unformatted=$$(gofmt -l cmd internal rules); \
	if [ -n "$$unformatted" ]; then \
	  printf 'Run make fmt to format:\n%s\n' "$$unformatted" >&2; exit 1; \
	fi

check: fmt-check vet license-check test

test:
	go test ./...
	$(MAKE) test-scripts

test-race:
	go test -race ./...
	$(MAKE) test-scripts

test-scripts:
	@command -v jq >/dev/null 2>&1 || { echo 'jq is required for script tests; install jq, then retry.' >&2; exit 1; }
	sh scripts/get_pod_images_test.sh
	sh scripts/download_test.sh

coverage:
	go test -race -coverpkg=./... -coverprofile=coverage.out ./...
	go tool cover -func=coverage.out

vet:
	go vet ./...

# Every Go and shell source starts with a one-line SPDX license identifier.
license-check:
	@missing=$$(git ls-files '*.go' '*.sh' | xargs grep -L 'SPDX-License-Identifier: MIT'); \
	if [ -n "$$missing" ]; then echo "missing SPDX-License-Identifier:" $$missing >&2; exit 1; fi

vuln:
	go run golang.org/x/vuln/cmd/govulncheck@latest ./...

lint: $(GOLANGCI_LINT)
	$(GOLANGCI_LINT) run

# Install the pinned golangci-lint if it is missing.
$(GOLANGCI_LINT):
	GOBIN=$(CURDIR)/bin go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)
	mv $(CURDIR)/bin/golangci-lint $@

# Cross-compile every entry in PLATFORMS into $(DISTDIR) as a .tar.gz, then
# write a sha256 checksum file covering all archives.
dist-all:
	@rm -rf $(DISTDIR)
	@mkdir -p $(DISTDIR)
	@set -eu; for p in $(PLATFORMS); do \
	  os=$${p%/*}; arch=$${p#*/}; \
	  echo "building $$os/$$arch"; \
	  GOOS=$$os GOARCH=$$arch CGO_ENABLED=0 \
	    go build -trimpath -ldflags '$(LDFLAGS)' -o $(DISTDIR)/$(BINARY) $(PKG) || exit 1; \
	  tar -czf $(DISTDIR)/$(BINARY)-$(VERSION)-$$os-$$arch.tar.gz -C $(DISTDIR) $(BINARY); \
	  rm -f $(DISTDIR)/$(BINARY); \
	done
	cd $(DISTDIR) && sha256sum *.tar.gz > checksums-$(VERSION).txt

clean:
	rm -rf $(DISTDIR) $(BINARY)
