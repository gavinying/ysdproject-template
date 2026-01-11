# Ysd Project Template

Encrypt `.env` files using SOPS + age with automatic git hooks. Zero Python dependency by default.

## Quick Start

### Get the template

- **New project (recommended)**: Click **Use this template** on GitHub to create a new repo from this template.
- **Existing repo**: Pull files down without history:
  ```bash
  curl -L https://github.com/gavinying/ysdproject-template/archive/refs/heads/main.tar.gz \
    | tar -xz --strip-components=1
  ```

```bash
# 1. Install tools (requires mise)
make setup

# 2. Configure encryption key
make setup-key      # If you have a key at $SOPS_AGE_KEY_FILE
# OR
make generate-key   # To create a new key

# 3. Create .env (plaintext stays gitignored); commit to add .env.sops
```

## How It Works

```
You edit:           Git commits:
─────────           ────────────
.env           →    .env.sops
```

- **On commit**: `.env` is automatically encrypted and staged as `.env.sops`
- **On checkout/pull**: `.env.sops` is automatically decrypted to `.env`
- **Plain `.env` is gitignored** so the unencrypted file never gets committed
- Decrypt backs up any existing plaintext to `.env.bak` before overwriting
- Need another env file? Run with `ENV_FILE=.env.stage make encrypt` and commit the resulting `.sops` file manually.
- For local overrides, create `.env.local`, `.env.stage`, etc. to layer on top of `.env`; they stay gitignored. Encrypt per-env files with `ENV_FILE=... make encrypt` only if you need to share them.

## Defaults and Tips

- Default target: `.env`. Override with `ENV_FILE=...` for other files.
- Hooks: `pre-commit` encrypts, `post-checkout`/`post-merge` decrypt.
- Layer local envs (`.env.local`, `.env.stage`, etc.) on top of `.env`; keep them unencrypted locally, encrypt only when they must be shared.
- Decrypt creates a safety backup (`.env.bak`) when a plaintext file already exists.
- Smart encrypt: skips re-encrypting if the content hash is unchanged; use `FORCE=1 make encrypt` to force regeneration.

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
| `make encrypt` | Encrypt `.env` → `.env.sops` (override with `ENV_FILE=...`) |
| `make decrypt` | Decrypt `.env.sops` → `.env` (backs up existing to `.env.bak`; override with `ENV_FILE=...`) |

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

The recommended workflow is to use your framework's initialization tool first, then layer this template on top.

1. **Initialize your project**:
   ```bash
   # Example: Next.js
   npx create-next-app@latest my-app
   cd my-app
   
   # Example: Python/Poetry
   poetry new my-app
   cd my-app
   ```

2. **Copy template files**:
   Copy the following files from this template into your new project root:
   - `Makefile`
   - `.sops.yaml`
   - `.tool-versions`
   - `.pre-commit-config.yaml` (optional)
   - `.gitignore` (merge with your existing gitignore)

3. **Setup Encryption**:
   ```bash
   # Install tools and hooks
   make setup
   
   # Generate a new key for this project
   make generate-key
   make setup-key
   ```

4. **Share & Commit**:
   - Share the private key (`~/.config/sops/age/keys.txt`) with your team via a secure channel (e.g., 1Password).
   - Create your `.env` file.
   - Run `make encrypt` (or commit, which triggers the hook) to create `.env.sops`.

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
