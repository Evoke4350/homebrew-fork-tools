# shellcheckignore=SC2129
# fork-tools Makefile
# Provides convenient commands for testing, building, and releasing

.PHONY: help test lint docker-test clean install release

# Default target
.DEFAULT_GOAL := help

# Variables
BATS ?= bats
DOCKER_COMPOSE ?= docker compose
SCRIPTS := fork-report.sh fork-check.sh fork-watcher.sh install.sh

##@ Help

help: ## Show this help message
	@echo "fork-tools - Makefile commands"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^###.*$$|^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

##@ Development

lint: ## Run shellcheck linting
	@echo "Running shellcheck..."
	@which shellcheck > /dev/null || (echo "Install shellcheck: brew install shellcheck" && exit 1)
	@find . -name '*.sh' -not -path './.git/*' -not -path './tests/*' -not -path './_site/*' | \
		while read f; do \
			echo "  Checking: $$f"; \
			shellcheck -x "$$f" || exit 1; \
		done
	@echo "✓ All files passed linting"

test: ## Run all tests locally
	@echo "Running test suite..."
	@if command -v bats > /dev/null 2>&1; then \
		$(BATS) tests/; \
	else \
		echo "BATS not installed. Run: brew install bats"; \
		echo "Or use: make docker-test"; \
		exit 1; \
	fi

test-unit: ## Run unit tests only
	@echo "Running unit tests..."
	@$(BATS) tests/test-utils.sh

test-integration: ## Run integration tests only
	@echo "Running integration tests..."
	@$(BATS) tests/test-integration.sh

test-verbose: ## Run tests with verbose output
	@echo "Running tests (verbose)..."
	@$(BATS) -r --print-output-on-failure tests/

syntax-check: ## Check bash syntax of all scripts
	@echo "Checking syntax..."
	@for script in $(SCRIPTS); do \
		echo "  $$script"; \
		bash -n "$$script" || exit 1; \
	done
	@echo "✓ Syntax check passed"

##@ Docker

docker-test: ## Run tests in Docker container
	@echo "Building and running tests in Docker..."
	@docker build -t fork-tools-test -f Dockerfile.test .
	@docker run --rm fork-tools-test

docker-lint: ## Run shellcheck in Docker
	@echo "Running shellcheck in Docker..."
	@$(DOCKER_COMPOSE) -f docker-compose.test.yml up shellcheck --build --abort-on-container-exit

docker-all: ## Run all Docker tests (multiple platforms)
	@echo "Running multi-platform Docker tests..."
	@$(DOCKER_COMPOSE) -f docker-compose.test.yml up --build --abort-on-container-exit

##@ Build

build: lint syntax-check test ## Run full build pipeline (lint -> syntax -> test)

ci: docker-all ## Run CI pipeline (Docker tests on all platforms)

##@ Installation

install: ## Install scripts to /usr/local/bin
	@echo "Installing fork-tools..."
	@for script in fork-report.sh fork-check.sh fork-watcher.sh; do \
		name=$${script%.sh}; \
		echo "  Installing $$name"; \
		cp "$$script" "/usr/local/bin/$$name"; \
		chmod +x "/usr/local/bin/$$name"; \
	done
	@echo "✓ Installed to /usr/local/bin"

uninstall: ## Remove scripts from /usr/local/bin
	@echo "Uninstalling fork-tools..."
	@rm -f /usr/local/bin/fork-report /usr/local/bin/fork-check /usr/local/bin/fork-watcher
	@echo "✓ Uninstalled"

##@ Clean

clean: ## Remove build artifacts
	@echo "Cleaning..."
	@rm -rf tests/tmp
	@rm -rf _site
	@find . -name "*.bak" -delete
	@echo "✓ Cleaned"

clean-docker: ## Remove Docker build artifacts
	@echo "Cleaning Docker artifacts..."
	@docker system prune -f
	@docker rmi fork-tools-test 2>/dev/null || true
	@echo "✓ Docker cleaned"
