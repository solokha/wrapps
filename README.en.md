# wrapps

[ru](README.md)

Portable NixOS environment and wrapped applications.

## Quick start

```bash
nix run github:solokha/wrapps/main#env
```

## Foreign host or live ISO

A clean system has neither private keys nor `nix-command`/flakes enabled, so
`nix run …#env` can fail before it starts, and the private repository cannot be
cloned without keys. `setup.sh` covers both: it enables flakes for its own nix
calls (without touching `/etc/nix/nix.conf`), restores the FIDO2 resident keys
from the token, and enters the environment.

```bash
curl -fsSLO https://raw.githubusercontent.com/solokha/wrapps/main/setup.sh
bash setup.sh
```

The same by hand:

```bash
export NIX_CONFIG='experimental-features = nix-command flakes'  # if flakes are off
mkdir -p ~/.ssh && cd ~/.ssh && ssh-keygen -K                   # keys from the token, PIN and touch
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
- Agent: `opencode` (v2, from `llm-agents.nix`)

## Telegram links

`t.me` pages hand out a `tg://join?invite=…` link, and Firefox cannot open that
scheme: a site may only claim `web+tg://`, and Telegram Web does not register it
for itself. So the system holds the scheme: `nixosModules.desktop` installs the
`tg-web` `.desktop` handler and points the XDG scheme database at it. The handler
rewrites the link into the deep link
`https://web.telegram.org/a/#?tgaddr=…` and opens it in the wrapped firefox —
the same one that runs the Telegram web app window.

## Secrets

`wrapps` is a public repository: credentials belong here **nowhere**. Everything
that lands in application defaults (agent, models, theme, fonts) is non-secret,
and that is checked on every edit.

Where secrets live once they appear:

- **In the applications themselves**, under a persistent `$HOME`: for example
  opencode credentials (`~/.local/share/opencode`) and the password of its local
  service (`~/.config/opencode/service.json`). They do not sit next to the repo.
- **Zed** keeps provider keys in the system secret store
  (secret-service / gnome-keyring), not in `settings.json`. No store — no saved
  key; that is a host configuration matter, not a wrapps one.
- **Per-host values from the environment**: endpoints and tokens reach the process
  as variables, and configs read them via `{env:...}` without hardcoding anything.
  The non-secret part lives in the host config, the secret part in a local
  git-ignored overlay.

On a **foreign host or in a live image** there are simply no secrets: wrapps lays
down non-secret defaults, and agents that need credentials ask to log in (opencode
ACP offers "Login with opencode", Zed has its own sign-in). Nothing breaks and no
secret travels anywhere.

## FIDO2

FIDO2 keys are used for SSH access. The environment starts
`wrapps-agent` and prompts when a PIN is needed.

The first time, restore the keys from the token:

```bash
mkdir -p ~/.ssh && cd ~/.ssh && ssh-keygen -K
```

`ssh-keygen -K` downloads the resident keys, writes both halves into the
current directory, and requires a token touch. Afterwards `wrapps-ssh-config`
adds them to `~/.ssh/config` unless the system already lists them.

Key order is visible on every push, so `wrapps-agent` owns it: `ssh` offers
the agent's keys to the server before the file ones and in the agent's own
order, and `@clone` (the one always at hand) is loaded first — otherwise the
first PIN and touch go to `@alone`, which is not. The ordered list is recorded
in the pidfile next to the socket: when it changes, the agent is restarted
instead of living on with a stale order.

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
