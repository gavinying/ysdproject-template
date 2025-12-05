# Environment Encryption with SOPS + age
# Zero Python dependency - works with pure bash git hooks
# Optional: Install pre-commit later for ecosystem hooks

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Default age key location
DEFAULT_AGE_KEY_FILE := $(HOME)/.config/sops/age/keys.txt

# Only encrypt/decrypt the main .env file (users can use .env.local etc. for overrides)
ENV_FILE := .env

#===============================================================================
# MAIN COMMANDS
#===============================================================================

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)Ysd Project Commands$(RESET)"
	@echo ""
	@echo "$(GREEN)Setup:$(RESET)"
	@grep -E '^(setup|install-tools|setup-key|generate-key):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Encryption:$(RESET)"
	@grep -E '^(encrypt|decrypt):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Git Hooks:$(RESET)"
	@grep -E '^(install-hooks|uninstall-hooks):.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'

.PHONY: setup
setup: install-tools install-hooks ## One-command setup: install tools + hooks
	@echo "$(GREEN)✓ Setup complete!$(RESET)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run 'make setup-key' to configure encryption key"
	@echo "  2. Create .env files and commit - they'll be encrypted automatically"

#===============================================================================
# TOOL INSTALLATION
#===============================================================================

.PHONY: install-tools
install-tools: ## Install sops and age via mise
	@if ! command -v mise >/dev/null 2>&1; then \
		echo "$(RED)Error: mise is not installed$(RESET)"; \
		echo ""; \
		echo "Install mise first:"; \
		echo "  curl https://mise.run | sh"; \
		echo ""; \
		echo "Or see: https://mise.jdx.dev/getting-started.html"; \
		exit 1; \
	fi
	@echo "$(CYAN)Installing tools via mise...$(RESET)"
	@mise install
	@echo "$(GREEN)✓ Tools installed$(RESET)"

#===============================================================================
# KEY MANAGEMENT
#===============================================================================

.PHONY: setup-key
setup-key: ## Extract public key from $$SOPS_AGE_KEY_FILE and update .sops.yaml
	@if [ -z "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(RED)Error: SOPS_AGE_KEY_FILE environment variable is not set$(RESET)"; \
		echo ""; \
		echo "Option 1: Generate a new key"; \
		echo "  $(CYAN)make generate-key$(RESET)"; \
		echo ""; \
		echo "Option 2: Set path to existing key"; \
		echo "  $(CYAN)export SOPS_AGE_KEY_FILE=/path/to/your/keys.txt$(RESET)"; \
		echo ""; \
		exit 1; \
	fi
	@if [ ! -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "$(RED)Error: Key file not found at $(SOPS_AGE_KEY_FILE)$(RESET)"; \
		exit 1; \
	fi
	@PUBLIC_KEY=$$(grep -o 'age1[a-z0-9]*' "$(SOPS_AGE_KEY_FILE)" | head -1); \
	if [ -z "$$PUBLIC_KEY" ]; then \
		echo "$(RED)Error: Could not extract public key from $(SOPS_AGE_KEY_FILE)$(RESET)"; \
		exit 1; \
	fi; \
	echo "$(CYAN)Public key: $$PUBLIC_KEY$(RESET)"; \
	if [ -f ".sops.yaml" ]; then \
		sed -i.bak "s/age: age1[a-z0-9]*/age: $$PUBLIC_KEY/" .sops.yaml && rm -f .sops.yaml.bak; \
		echo "$(GREEN)✓ Updated .sops.yaml with public key$(RESET)"; \
	else \
		echo "$(RED)Error: .sops.yaml not found$(RESET)"; \
		exit 1; \
	fi

.PHONY: generate-key
generate-key: ## Generate new age key at default location
	@mkdir -p $(dir $(DEFAULT_AGE_KEY_FILE))
	@if [ -f "$(DEFAULT_AGE_KEY_FILE)" ]; then \
		echo "$(YELLOW)Warning: Key already exists at $(DEFAULT_AGE_KEY_FILE)$(RESET)"; \
		echo "Remove it first if you want to generate a new one."; \
		exit 1; \
	fi
	@age-keygen -o $(DEFAULT_AGE_KEY_FILE)
	@chmod 600 $(DEFAULT_AGE_KEY_FILE)
	@echo ""
	@echo "$(GREEN)✓ Key generated at $(DEFAULT_AGE_KEY_FILE)$(RESET)"
	@echo ""
	@echo "Add this to your shell profile (.bashrc, .zshrc, etc.):"
	@echo "  $(CYAN)export SOPS_AGE_KEY_FILE=$(DEFAULT_AGE_KEY_FILE)$(RESET)"
	@echo ""
	@echo "Then run: $(CYAN)make setup-key$(RESET)"

#===============================================================================
# ENCRYPTION / DECRYPTION
#===============================================================================

# Option: FORCE=1 to re-encrypt even if unchanged
FORCE ?=

.PHONY: encrypt
encrypt: ## Encrypt .env file (smart mode). Use FORCE=1 to re-encrypt.
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(YELLOW)No $(ENV_FILE) file found to encrypt$(RESET)"; \
		exit 0; \
	fi
	@current_hash=$$(sha256sum "$(ENV_FILE)" | cut -d' ' -f1); \
	stored_hash=""; \
	if [ -z "$(FORCE)" ] && [ -f "$(ENV_FILE).hash" ]; then \
		stored_hash=$$(cat "$(ENV_FILE).hash" 2>/dev/null || echo ""); \
	fi; \
	if [ "$$current_hash" != "$$stored_hash" ]; then \
		echo "$(CYAN)Encrypting $(ENV_FILE) -> $(ENV_FILE).sops$(RESET)"; \
		sops --encrypt --input-type dotenv --output-type dotenv "$(ENV_FILE)" > "$(ENV_FILE).sops"; \
		echo "$$current_hash" > "$(ENV_FILE).hash"; \
	fi
	@echo "$(GREEN)✓ Encryption complete$(RESET)"

.PHONY: decrypt
decrypt: ## Decrypt .env.sops file (creates .env, backs up existing to .env.bak)
	@if [ ! -f "$(ENV_FILE).sops" ]; then \
		echo "$(YELLOW)No $(ENV_FILE).sops file found to decrypt$(RESET)"; \
		exit 0; \
	fi
	@if [ -f "$(ENV_FILE)" ]; then \
		cp "$(ENV_FILE)" "$(ENV_FILE).bak"; \
		echo "$(YELLOW)Backed up $(ENV_FILE) -> $(ENV_FILE).bak$(RESET)"; \
	fi
	@echo "$(CYAN)Decrypting $(ENV_FILE).sops -> $(ENV_FILE)$(RESET)"
	@sops --decrypt --input-type dotenv --output-type dotenv "$(ENV_FILE).sops" > "$(ENV_FILE)"
	@echo "$(GREEN)✓ Decryption complete$(RESET)"

#===============================================================================
# GIT HOOKS
#===============================================================================

.PHONY: install-hooks
install-hooks: ## Install git hooks for automatic encrypt/decrypt
	@if [ ! -d ".git" ]; then \
		echo "$(RED)Error: Not a git repository$(RESET)"; \
		exit 1; \
	fi
	@mkdir -p .git/hooks
	@# Pre-commit hook
	@echo '#!/bin/bash' > .git/hooks/pre-commit
	@echo '# Auto-generated by make install-hooks' >> .git/hooks/pre-commit
	@echo 'make encrypt && git add .env.sops 2>/dev/null || true' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@# Post-checkout hook
	@echo '#!/bin/bash' > .git/hooks/post-checkout
	@echo '# Auto-generated by make install-hooks' >> .git/hooks/post-checkout
	@echo 'make decrypt' >> .git/hooks/post-checkout
	@chmod +x .git/hooks/post-checkout
	@# Post-merge hook
	@echo '#!/bin/bash' > .git/hooks/post-merge
	@echo '# Auto-generated by make install-hooks' >> .git/hooks/post-merge
	@echo 'make decrypt' >> .git/hooks/post-merge
	@chmod +x .git/hooks/post-merge
	@echo "$(GREEN)✓ Git hooks installed$(RESET)"

.PHONY: uninstall-hooks
uninstall-hooks: ## Remove git hooks
	@rm -f .git/hooks/pre-commit .git/hooks/post-checkout .git/hooks/post-merge
	@echo "$(GREEN)✓ Git hooks removed$(RESET)"
