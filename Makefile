# YSD project template automation
#
# Scope:
# - Keep this Makefile focused on common bootstrap and env management.
# - Run app/framework commands from package.json directly, for example
#   `pnpm dev`, `pnpm build`, `pnpm test:all:local`, or project-specific scripts.
# - Add only truly common Make targets here. Put product, deploy, Cloudflare,
#   database, test matrix, and app-specific automation in package.json scripts or
#   scripts/* helpers.
#
# AI extension guide:
# - Prefer extending package.json scripts before adding Make targets.
# - Keep env source files as the truth, then generate runtime files via an
#   `env:sync` package script or scripts/env-sync.mjs helper when needed.
# - Do not hand-edit generated env/runtime files such as .dev.vars or generated
#   wrangler config.
# - Avoid staging/prod or provider-specific targets in this template. Add them in
#   the concrete project only when the project has a runbook for them.

.DEFAULT_GOAL := help

SHELL := /bin/bash

CYAN   := $(shell printf '\033[36m')
GREEN  := $(shell printf '\033[32m')
YELLOW := $(shell printf '\033[33m')
RED    := $(shell printf '\033[31m')
RESET  := $(shell printf '\033[0m')

AGE_KEY_FILE      := $(HOME)/.config/sops/age/keys.txt
SOPS_AGE_KEY_FILE ?= $(AGE_KEY_FILE)

# Plaintext env sources. Keep these gitignored.
# Extend in a concrete project when needed, for example:
#   ENV_FILES := .env .env*.local apps/app/.env apps/app/.env*.local
ENV_FILES ?= .env .env*.local

# Encrypted env files. Commit these when .sops.yaml is configured correctly.
SOPS_FILES ?= $(patsubst %,%.sops,$(ENV_FILES))

# Set FORCE=1 to re-encrypt unchanged env files.
FORCE ?=

# Set BACKUP=0 to overwrite plaintext env files during decrypt without backups.
BACKUP ?= 1

# Common local dev ports. Override in a concrete project when needed, for example:
#   DEV_PORTS := 3000 4321 8787 8000
DEV_PORTS ?= 3000 4321 8787

#===============================================================================
# HELP
#===============================================================================

.PHONY: help
help: ## Show this command index
	@echo "$(CYAN)YSD project template$(RESET)"
	@echo ""
	@echo "$(GREEN)Setup$(RESET)"
	@grep -E '^(setup|doctor|install-tools|install-deps|generate-key|setup-key):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Environment$(RESET)"
	@grep -E '^(env-list|env-check-key|env-encrypt|env-decrypt|env-sync|encrypt|decrypt):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Local utilities$(RESET)"
	@grep -E '^(kill-ports):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Run app commands from package.json directly, for example: pnpm dev, pnpm build, pnpm test.$(RESET)"

#===============================================================================
# SETUP
#===============================================================================

.PHONY: setup
setup: install-tools setup-key install-deps env-decrypt env-sync ## Common bootstrap: tools, key, deps, env
	@echo "$(GREEN)✓ Setup complete$(RESET)"

.PHONY: doctor
doctor: ## Check common tools, env key, and optional app sync hooks
	@echo "$(CYAN)Checking common project tooling...$(RESET)"
	@command -v mise >/dev/null 2>&1 && echo "$(GREEN)✓ mise$(RESET)" || echo "$(RED)✗ mise missing$(RESET)"
	@command -v sops >/dev/null 2>&1 && echo "$(GREEN)✓ sops$(RESET)" || echo "$(YELLOW)! sops unavailable until mise install runs$(RESET)"
	@command -v age-keygen >/dev/null 2>&1 && echo "$(GREEN)✓ age$(RESET)" || echo "$(YELLOW)! age unavailable until mise install runs$(RESET)"
	@if [ -f package.json ]; then \
		command -v pnpm >/dev/null 2>&1 && echo "$(GREEN)✓ pnpm$(RESET)" || echo "$(RED)✗ package.json exists but pnpm is missing$(RESET)"; \
	else \
		echo "$(YELLOW)! package.json not present$(RESET)"; \
	fi
	@if [ -f pyproject.toml ]; then \
		command -v uv >/dev/null 2>&1 && echo "$(GREEN)✓ uv$(RESET)" || echo "$(RED)✗ pyproject.toml exists but uv is missing$(RESET)"; \
	fi
	@if [ -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(GREEN)✓ SOPS age key: $(SOPS_AGE_KEY_FILE)$(RESET)"; \
	else \
		echo "$(YELLOW)! SOPS age key not found: $(SOPS_AGE_KEY_FILE)$(RESET)"; \
	fi
	@if [ -f package.json ] && command -v pnpm >/dev/null 2>&1 && pnpm --silent run | grep -q '^  env:sync'; then \
		echo "$(GREEN)✓ env:sync package script$(RESET)"; \
	elif [ -f scripts/env-sync.mjs ]; then \
		echo "$(GREEN)✓ scripts/env-sync.mjs$(RESET)"; \
	else \
		echo "$(YELLOW)! no env sync hook configured$(RESET)"; \
	fi

.PHONY: install-tools
install-tools: ## Install tools declared in .mise.toml
	@if ! command -v mise >/dev/null 2>&1; then \
		echo "$(RED)Error: mise is not installed$(RESET)"; \
		echo "Install: curl https://mise.run | sh"; \
		exit 1; \
	fi
	@echo "$(CYAN)Installing toolchain via mise...$(RESET)"
	@mise install
	@echo "$(GREEN)✓ Toolchain ready$(RESET)"

.PHONY: install-deps
install-deps: ## Install dependencies if package.json or pyproject.toml exists
	@if [ -f package.json ]; then \
		if command -v pnpm >/dev/null 2>&1; then \
			echo "$(CYAN)Installing Node dependencies with pnpm...$(RESET)"; \
			pnpm install; \
		else \
			echo "$(YELLOW)package.json found, but pnpm is unavailable$(RESET)"; \
		fi; \
	fi
	@if [ -f pyproject.toml ]; then \
		if command -v uv >/dev/null 2>&1; then \
			echo "$(CYAN)Installing Python dependencies with uv...$(RESET)"; \
			uv sync --locked || uv sync; \
		else \
			echo "$(YELLOW)pyproject.toml found, but uv is unavailable$(RESET)"; \
		fi; \
	fi
	@if [ ! -f package.json ] && [ ! -f pyproject.toml ]; then \
		echo "$(YELLOW)No package.json or pyproject.toml found; skipping dependency install$(RESET)"; \
	fi

#===============================================================================
# KEY MANAGEMENT
#===============================================================================

.PHONY: generate-key
generate-key: ## Generate a new age key at ~/.config/sops/age/keys.txt
	@[ ! -f "$(AGE_KEY_FILE)" ] || { echo "$(RED)Key already exists: $(AGE_KEY_FILE)$(RESET)"; exit 1; }
	@mkdir -p "$(dir $(AGE_KEY_FILE))"
	@age-keygen -o "$(AGE_KEY_FILE)"
	@chmod 600 "$(AGE_KEY_FILE)"
	@echo "$(GREEN)✓ Key generated: $(AGE_KEY_FILE)$(RESET)"
	@echo "Add to shell profile: $(CYAN)export SOPS_AGE_KEY_FILE=$(AGE_KEY_FILE)$(RESET)"
	@echo "Then run: $(CYAN)make setup-key$(RESET)"

.PHONY: setup-key
setup-key: ## Update .sops.yaml with the public key from $$SOPS_AGE_KEY_FILE
	@[ -f "$(SOPS_AGE_KEY_FILE)" ] || { \
		echo "$(RED)Key not found: $(SOPS_AGE_KEY_FILE)$(RESET)"; \
		echo "Run $(CYAN)make generate-key$(RESET) or export SOPS_AGE_KEY_FILE=/path/to/keys.txt"; \
		exit 1; \
	}
	@PUBLIC_KEY=$$(grep -o 'age1[a-z0-9]*' "$(SOPS_AGE_KEY_FILE)" | head -1); \
	[ -n "$$PUBLIC_KEY" ] || { echo "$(RED)Could not read public key from $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }; \
	[ -f .sops.yaml ] || { echo "$(RED).sops.yaml not found$(RESET)"; exit 1; }; \
	sed -i.bak -E "s/(age: |- )age1[a-z0-9]+/\1$$PUBLIC_KEY/" .sops.yaml && rm -f .sops.yaml.bak; \
	echo "$(GREEN)✓ .sops.yaml updated ($$PUBLIC_KEY)$(RESET)"

.PHONY: env-check-key
env-check-key: ## Verify the configured age key exists and is readable
	@[ -f "$(SOPS_AGE_KEY_FILE)" ] || { echo "$(RED)Missing key: $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }
	@grep -q 'AGE-SECRET-KEY-' "$(SOPS_AGE_KEY_FILE)" || { echo "$(RED)Invalid age key file: $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }
	@echo "$(GREEN)✓ SOPS age key is available$(RESET)"

#===============================================================================
# ENVIRONMENT MANAGEMENT
#===============================================================================

.PHONY: env-list
env-list: ## List plaintext and encrypted env files managed by this template
	@echo "$(CYAN)Plaintext env sources (gitignored):$(RESET)"
	@found=0; for f in $(ENV_FILES); do [ -f "$$f" ] || continue; found=1; echo "  $$f"; done; \
	[ "$$found" -eq 1 ] || echo "  (none found)"
	@echo "$(CYAN)Encrypted env files:$(RESET)"
	@found=0; for f in $(SOPS_FILES); do [ -f "$$f" ] || continue; found=1; echo "  $$f"; done; \
	[ "$$found" -eq 1 ] || echo "  (none found)"

.PHONY: env-encrypt
env-encrypt: ## Encrypt env sources to *.sops; use FORCE=1 to re-encrypt
	@found=0; \
	for f in $(ENV_FILES); do \
		[ -f "$$f" ] || continue; found=1; \
		current=$$(sha256sum "$$f" | cut -d' ' -f1); \
		stored=$$(cat "$$f.hash" 2>/dev/null || echo ""); \
		if [ -z "$(FORCE)" ] && [ "$$current" = "$$stored" ]; then \
			echo "$(GREEN)✓ $$f unchanged, skipping$(RESET)"; \
		else \
			echo "$(CYAN)Encrypting $$f -> $$f.sops$(RESET)"; \
			SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --encrypt --input-type dotenv --output-type dotenv "$$f" > "$$f.sops"; \
			echo "$$current" > "$$f.hash"; \
		fi; \
	done; \
	[ "$$found" -eq 1 ] || echo "$(YELLOW)No env files matched: $(ENV_FILES)$(RESET)"

.PHONY: env-decrypt
env-decrypt: ## Decrypt *.sops files to plaintext env files; use BACKUP=0 to skip backups
	@found=0; \
	for f in $(SOPS_FILES); do \
		[ -f "$$f" ] || continue; found=1; \
		out=$${f%.sops}; \
		if [ "$(BACKUP)" != "0" ] && [ -f "$$out" ]; then \
			cp "$$out" "$$out.bak"; \
			echo "$(YELLOW)Backed up $$out -> $$out.bak$(RESET)"; \
		fi; \
		echo "$(CYAN)Decrypting $$f -> $$out$(RESET)"; \
		SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --decrypt --input-type dotenv --output-type dotenv "$$f" > "$$out"; \
	done; \
	[ "$$found" -eq 1 ] && echo "$(GREEN)✓ Decryption complete$(RESET)" || echo "$(YELLOW)No encrypted env files matched: $(SOPS_FILES)$(RESET)"

.PHONY: encrypt
encrypt: env-encrypt ## Alias for env-encrypt

.PHONY: decrypt
decrypt: env-decrypt ## Alias for env-decrypt

.PHONY: env-sync
env-sync: ## Run env sync hook if package.json or scripts/env-sync.mjs defines one
	@if [ -f package.json ] && command -v pnpm >/dev/null 2>&1 && pnpm --silent run | grep -q '^  env:sync'; then \
		echo "$(CYAN)Running package script env:sync...$(RESET)"; \
		pnpm env:sync; \
	elif [ -f scripts/env-sync.mjs ]; then \
		echo "$(CYAN)Running scripts/env-sync.mjs...$(RESET)"; \
		node scripts/env-sync.mjs; \
	else \
		echo "$(YELLOW)No env sync hook found; skipping$(RESET)"; \
		echo "Add package script $(CYAN)env:sync$(RESET) or $(CYAN)scripts/env-sync.mjs$(RESET) when the project needs generated runtime env files."; \
	fi

#===============================================================================
# LOCAL UTILITIES
#===============================================================================

.PHONY: kill-ports
kill-ports: ## Kill processes on common local dev ports; override DEV_PORTS per project
	@for port in $(DEV_PORTS); do \
		pid=$$(lsof -ti :$$port 2>/dev/null || true); \
		if [ -n "$$pid" ]; then \
			kill -9 $$pid && echo "$(GREEN)✓ Killed PID $$pid on :$$port$(RESET)"; \
		else \
			echo "  Nothing on :$$port"; \
		fi; \
	done
