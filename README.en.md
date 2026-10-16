# wrapps

[ru](README.md)

Portable NixOS environment and wrapped applications.

## Quick start

```bash
nix run github:solokha/wrapps/main#env
```

## Contents

- `env` — development environment with tools and wrapped packages
- `shell` — interactive shell with environment loaded
- `denv` — direct environment launcher
- `desktop` — full desktop environment
- `noctalia` — theme collection

## Packages

- Terminal: `foot`, `zellij`, `helix`
- Desktop: `niri`, `fuzzel`, `zed`
- Browser: `firefox`
- Tools: `git`, `lazygit`, `btop`, `eza`, `ripgrep`, `fzf`

## FIDO2

FIDO2 keys are used for SSH and commit signing. The environment starts
`wrapps-agent` and prompts when a PIN is needed.

The first time, restore the keys from the token:

```bash
mkdir -p ~/.ssh && cd ~/.ssh && ssh-keygen -K
```

`ssh-keygen -K` downloads the resident keys, writes both halves into the
current directory, and requires a token touch. Afterwards `wrapps-ssh-config`
adds them to `~/.ssh/config` unless the system already lists them.

The private key files on disk are handle files only (empty) — the secret
itself stays on the token.

## Usage

```bash
# Enter environment
nix run github:solokha/wrapps/main#env

# Run specific tool
nix run github:solokha/wrapps/main#env -- git status

# Desktop environment
nix run github:solokha/wrapps/main#desktop
```
