# project automation
# Requires: sops, age
#
# Env files remain app-local. Make/SOPS automation is centralized at repo root.

.DEFAULT_GOAL := help

CYAN  := \033[36m
GREEN := \033[32m
RED   := \033[31m
RESET := \033[0m

SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt
APPS_ROOT         ?= 
MAKEFILE_DIR      := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
DISPLAY_CURDIR    := $(if $(filter $(MAKEFILE_DIR),$(CURDIR)),.,$(patsubst $(MAKEFILE_DIR)/%,%,$(CURDIR)))
SOPS_CONFIG       := $(MAKEFILE_DIR)/.sops.yaml
SOPS_ENV_PATH_REGEX := (^|.*/)\.env(\..*\.local)?$

#===============================================================================
# HELP
#===============================================================================

.PHONY: help
help:
	@echo "$(CYAN)Ysd app$(RESET)"
	@echo ""
	@echo "$(CYAN)── Setup$(RESET)"
	@echo "  $(CYAN)make generate-key$(RESET)           Generate a new age key at $$SOPS_AGE_KEY_FILE (or default path)"
	@echo "  $(CYAN)make check-age-key$(RESET)          Verify the age key is present in root .sops.yaml"
	@echo "  $(CYAN)make setup-sops$(RESET)             Append the age public key to the apps SOPS rule"
	@echo ""
	@echo "$(CYAN)── Env$(RESET)"
	@echo "  $(CYAN)make env-sync$(RESET)               Sync current dir, then APPS_ROOT/* dirs when APPS_ROOT is set"
	@echo "  $(CYAN)make env-encrypt$(RESET)            Encrypt current dir, then APPS_ROOT/* dirs when APPS_ROOT is set"
	@echo "  $(CYAN)make env-decrypt$(RESET)            Decrypt current dir, then APPS_ROOT/* dirs when APPS_ROOT is set"
	@echo "  $(CYAN)make app-env-encrypt$(RESET)        Encrypt apps/app env files"
	@echo "  $(CYAN)make backend-env-encrypt$(RESET)    Encrypt apps/backend env files"
	@echo "  $(CYAN)make dev$(RESET)                    Start backend (:8000) and app (:3000)"
	@echo "  $(CYAN)make kill-ports$(RESET)             Kill processes on dev ports (3000, 8000, 8787)"
	@echo "  $(CYAN)make build$(RESET)                  env-encrypt + env-sync + workspace build"

.PHONY: check-age-key
check-age-key: ## Verify SOPS_AGE_KEY_FILE exists and matches a root .sops.yaml age recipient
	@[ -f "$(SOPS_AGE_KEY_FILE)" ] || { echo "$(RED)Key not found: $(SOPS_AGE_KEY_FILE). Run: make generate-key or set SOPS_AGE_KEY_FILE$(RESET)"; exit 1; }
	@echo "$(CYAN)Using key file: $(SOPS_AGE_KEY_FILE)$(RESET)"
	@PUBLIC_KEY=$$(grep -o 'age1[a-z0-9]*' "$(SOPS_AGE_KEY_FILE)" | head -1); \
		[ -n "$$PUBLIC_KEY" ] || { echo "$(RED)Could not read public key from $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }; \
		grep -q -- "- $$PUBLIC_KEY" "$(SOPS_CONFIG)" && echo "$(GREEN)✓ age key configured ($$PUBLIC_KEY)$(RESET)" || { echo "$(RED)Public key not configured in $(SOPS_CONFIG): $$PUBLIC_KEY$(RESET)"; exit 1; }

.PHONY: setup-sops
setup-sops: ## Append the age public key to the apps SOPS rule
	@[ -f "$(SOPS_AGE_KEY_FILE)" ] || { echo "$(RED)Key not found: $(SOPS_AGE_KEY_FILE). Run: make generate-key$(RESET)"; exit 1; }
	@PUBLIC_KEY=$$(grep -o 'age1[a-z0-9]*' "$(SOPS_AGE_KEY_FILE)" | head -1); \
		[ -n "$$PUBLIC_KEY" ] || { echo "$(RED)Could not read public key$(RESET)"; exit 1; }; \
		node "$(MAKEFILE_DIR)/scripts/sops-add-age-recipient.mjs" "$(SOPS_CONFIG)" "$(SOPS_ENV_PATH_REGEX)" "$$PUBLIC_KEY"

.PHONY: app-setup-sops backend-setup-sops
app-setup-sops backend-setup-sops: setup-sops ## Backward-compatible aliases for setup-sops

.PHONY: generate-key
generate-key: ## Generate a new age key at $$SOPS_AGE_KEY_FILE (or default path)
	@[ ! -f "$(SOPS_AGE_KEY_FILE)" ] || { echo "$(RED)Key already exists: $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }
	@mkdir -p $(dir $(SOPS_AGE_KEY_FILE))
	@age-keygen -o $(SOPS_AGE_KEY_FILE)
	@chmod 600 $(SOPS_AGE_KEY_FILE)
	@echo "$(GREEN)✓ Key generated: $(SOPS_AGE_KEY_FILE)$(RESET)"
	@echo "    Add to shell profile: export SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE)"

#===============================================================================
# ENV
#===============================================================================

.PHONY: env-sync env-sync-current app-env-sync backend-env-sync
env-sync: ## Sync current dir, then APPS_ROOT/* dirs when APPS_ROOT is set
	@$(MAKE) --no-print-directory env-sync-current
	@if [ -n "$(APPS_ROOT)" ]; then \
		found=0; \
		for dir in "$(APPS_ROOT)"/*; do \
			[ -d "$$dir" ] || continue; found=1; \
			$(MAKE) --no-print-directory -C "$$dir" -f "$(MAKEFILE_DIR)/Makefile" env-sync-current || exit $$?; \
		done; \
		[ "$$found" -eq 1 ] || echo "No directories found under $(APPS_ROOT)"; \
	fi

env-sync-current: ## Sync env in the current directory
	@if [ -f "wrangler.jsonc" ]; then \
		echo "$(CYAN)Syncing $(DISPLAY_CURDIR) env$(RESET)"; \
		node "$(MAKEFILE_DIR)/scripts/env-sync.mjs"; \
	else \
		echo "$(CYAN)✓ $(DISPLAY_CURDIR) env sync is not configured. Skipping.$(RESET)"; \
	fi

app-env-sync: ## Sync apps/app env only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/app" -f "$(MAKEFILE_DIR)/Makefile" env-sync-current
backend-env-sync: ## Sync apps/backend env only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/backend" -f "$(MAKEFILE_DIR)/Makefile" env-sync-current

.PHONY: env-encrypt env-encrypt-current app-env-encrypt backend-env-encrypt
env-encrypt: ## Encrypt current dir, then APPS_ROOT/* dirs when APPS_ROOT is set
	@$(MAKE) --no-print-directory env-encrypt-current
	@if [ -n "$(APPS_ROOT)" ]; then \
		found=0; \
		for dir in "$(APPS_ROOT)"/*; do \
			[ -d "$$dir" ] || continue; found=1; \
			$(MAKE) --no-print-directory -C "$$dir" -f "$(MAKEFILE_DIR)/Makefile" env-encrypt-current || exit $$?; \
		done; \
		[ "$$found" -eq 1 ] || echo "No directories found under $(APPS_ROOT)"; \
	fi

env-encrypt-current: ## Encrypt env files in the current directory
	@found=0; \
	for f in .env .env*.local; do \
		[ -f "$$f" ] || continue; found=1; \
		if [ "$(DISPLAY_CURDIR)" = "." ]; then \
			display_path="$$f"; \
		else \
			display_path="$(DISPLAY_CURDIR)/$$f"; \
		fi; \
		current=$$(sha256sum "$$f" | cut -d' ' -f1); \
		stored=$$(cat "$$f.hash" 2>/dev/null || echo ""); \
		if [ "$$current" = "$$stored" ]; then \
			echo "$(GREEN)✓ $$display_path unchanged, skipping$(RESET)"; \
		else \
			echo "$(CYAN)Encrypting $$display_path → $$display_path.sops$(RESET)"; \
			sops --config "$(SOPS_CONFIG)" --encrypt --input-type dotenv --output-type dotenv "$$f" > "$$f.sops"; \
			echo "$$current" > "$$f.hash"; \
		fi; \
	done; \
	[ "$$found" -eq 1 ] || echo "No env files found in $(DISPLAY_CURDIR)"

app-env-encrypt: ## Encrypt apps/app env files only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/app" -f "$(MAKEFILE_DIR)/Makefile" env-encrypt-current
backend-env-encrypt: ## Encrypt apps/backend env files only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/backend" -f "$(MAKEFILE_DIR)/Makefile" env-encrypt-current

.PHONY: validate-age-secret-key env-decrypt env-decrypt-current app-env-decrypt backend-env-decrypt
validate-age-secret-key:
	@[ -f "$(SOPS_AGE_KEY_FILE)" ] || { echo "$(RED)SOPS age key file not found: $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }
	@grep -q 'AGE-SECRET-KEY-' "$(SOPS_AGE_KEY_FILE)" || { echo "$(RED)No AGE-SECRET-KEY entry found in $(SOPS_AGE_KEY_FILE)$(RESET)"; exit 1; }
	@key_path=$$(realpath "$(SOPS_AGE_KEY_FILE)" 2>/dev/null || echo "$(SOPS_AGE_KEY_FILE)"); \
		echo "$(CYAN)Using age key: $$key_path$(RESET)"

env-decrypt: validate-age-secret-key ## Decrypt current dir, then APPS_ROOT/* dirs when APPS_ROOT is set
	@$(MAKE) --no-print-directory env-decrypt-current
	@if [ -n "$(APPS_ROOT)" ]; then \
		found=0; \
		for dir in "$(APPS_ROOT)"/*; do \
			[ -d "$$dir" ] || continue; found=1; \
			$(MAKE) --no-print-directory -C "$$dir" -f "$(MAKEFILE_DIR)/Makefile" env-decrypt-current || exit $$?; \
		done; \
		[ "$$found" -eq 1 ] || echo "No directories found under $(APPS_ROOT)"; \
	fi

env-decrypt-current: ## Decrypt *.sops in the current directory
	@found=0; \
	for f in .env.sops .env*.local.sops; do \
		[ -f "$$f" ] || continue; found=1; \
		SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" node "$(MAKEFILE_DIR)/scripts/sops-decrypt-dotenv.mjs" "$(SOPS_CONFIG)" "$$f" || exit $$?; \
	done; \
	[ "$$found" -eq 1 ] || echo "No *.sops files found in $(DISPLAY_CURDIR)"

app-env-decrypt: validate-age-secret-key ## Decrypt apps/app env files only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/app" -f "$(MAKEFILE_DIR)/Makefile" env-decrypt-current
backend-env-decrypt: validate-age-secret-key ## Decrypt apps/backend env files only
	@$(MAKE) --no-print-directory -C "$(MAKEFILE_DIR)/apps/backend" -f "$(MAKEFILE_DIR)/Makefile" env-decrypt-current

#===============================================================================
# DEVELOPMENT
#===============================================================================

.PHONY: build
build: ## Encrypt/sync apps envs then build all packages
	@$(MAKE) --no-print-directory env-encrypt APPS_ROOT=apps
	@$(MAKE) --no-print-directory env-sync APPS_ROOT=apps
	@pnpm contracts:app:check
	@pnpm contracts:backend:check
	@pnpm type-check
	@pnpm exec turbo build

.PHONY: dev
dev: kill-ports ## Start backend and app dev servers
	@$(MAKE) --no-print-directory env-sync APPS_ROOT=apps
	@echo "$(CYAN)Starting backend (:8000) and app (:3000)$(RESET)"
	@pnpm --filter backend run dev & \
		backend_pid=$$!; \
		pnpm --filter app run dev & \
		app_pid=$$!; \
		trap 'kill $$backend_pid $$app_pid 2>/dev/null || true; wait $$backend_pid $$app_pid 2>/dev/null || true' INT TERM EXIT; \
		wait $$backend_pid $$app_pid

.PHONY: kill-ports
kill-ports: ## Kill processes on dev ports (3000 Vite, 8000 backend, 8787 Wrangler inspector)
	@for port in 3000 8000 8787; do \
		pid=$$(lsof -ti :$$port 2>/dev/null); \
		if [ -n "$$pid" ]; then \
			kill -9 $$pid && echo "$(GREEN)✓ Killed PID $$pid on :$$port$(RESET)"; \
		else \
			echo "  Nothing on :$$port"; \
		fi; \
	done
