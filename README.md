# Environment Encryption Template

Encrypt `.env` files using SOPS + age with automatic git hooks. Zero Python dependency by default.

## Quick Start

```bash
# 1. Install tools (requires mise)
make setup

# 2. Configure encryption key
make setup-key      # If you have a key at $SOPS_AGE_KEY_FILE
# OR
make generate-key   # To create a new key

# 3. Create .env files and commit - encryption is automatic!
```

## How It Works

```
You edit:           Git commits:
─────────           ────────────
.env          →     .env.sops
.env.local    →     .env.local.sops
.env.prod     →     .env.prod.sops
```

- **On commit**: `.env*` files are automatically encrypted and staged
- **On checkout/pull**: Encrypted files are automatically decrypted
- **Unencrypted `.env` files are gitignored** - they never get committed

## Commands

### Setup

| Command | Description |
|---------|-------------|
| `make setup` | One-command setup: install tools + hooks |
| `make install-tools` | Install sops and age via mise |
| `make install-hooks` | Install git hooks |
| `make uninstall-hooks` | Remove git hooks |

### Key Management

| Command | Description |
|---------|-------------|
| `make generate-key` | Create new age key at `~/.config/sops/age/keys.txt` |
| `make setup-key` | Extract public key and update `.sops.yaml` |

### Encryption

| Command | Description |
|---------|-------------|
| `make encrypt` | Manually encrypt all `.env*` files |
| `make decrypt` | Manually decrypt all `.env*.sops` files |

## Joining an Existing Project

1. Get the private key from your team (via secure channel)
2. Save it to `~/.config/sops/age/keys.txt`
3. Set the environment variable:
   ```bash
   export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
   ```
4. Run:
   ```bash
   make setup
   make decrypt
   ```

## Starting a New Project

1. Copy template files to your project
2. Run:
   ```bash
   make setup
   make generate-key
   make setup-key
   ```
3. Share the private key with your team via secure channel
4. Create `.env` files and commit

## Optional: Pre-commit Integration

This template works without Python. If you want ecosystem hooks (linting, formatting):

```bash
pip install pre-commit
pre-commit install
```

The encryption will continue to work - it's already configured in `.pre-commit-config.yaml`.

## Files in This Template

| File | Purpose |
|------|---------|
| `Makefile` | All commands and git hook logic |
| `.tool-versions` | mise tool versions (sops, age) |
| `.sops.yaml` | SOPS encryption configuration |
| `.pre-commit-config.yaml` | Pre-commit config (optional) |
| `.gitignore` | Ignores unencrypted `.env` files |
| `.editorconfig` | Editor settings |

## What Gets Encrypted

The `.sops.yaml` encrypts values whose keys match:

- `*KEY*`, `*SECRET*`, `*PASSWORD*`, `*TOKEN*`
- `*CREDENTIALS*`, `*API*`, `*AUTH*`, `*PRIVATE*`
- `*CERT*`, `*SIGNING*`, `*ENCRYPTION*`, `*HASH*`, `*SALT*`
- `*CONNECTION*`, `*DSN*`, `*URL*`, `*URI*`

Non-sensitive keys (like `DEBUG=true`) remain readable in the encrypted file.

## Troubleshooting

### "mise is not installed"

Install mise first: https://mise.jdx.dev/getting-started.html

```bash
curl https://mise.run | sh
```

### "SOPS_AGE_KEY_FILE is not set"

Add to your shell profile (`.bashrc`, `.zshrc`):

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
```

### "Could not decrypt"

Make sure you have the correct private key that matches the public key in `.sops.yaml`.

