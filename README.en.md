# wrapps

[Русский](README.md)

Portable desktop environment, wrapped packages, and a shell for working with keys
(ssh / sops / age). A Nix flake that runs on any machine with Nix — no system
installation required.

## What's inside

| Package | What it is |
|---|---|
| `#env` | Portable shell: bash, git, hx, nh, tmux, sops/age/ssh, prompt and history |
| `#desktop` | Session entry point: greetd + niri + noctalia |
| `#foot`, `#fuzzel` | Terminal and launcher with the noctalia theme |
| `#niri`, `#noctalia` | Compositor and desktop shell |
| `#firefox`, `#kitty`, `#zed`, `#helix`, `#zellij` | Wrapped applications |
| `#nh` | NixOS configuration helper |
| `#nixos-anywhere` | Host reinstall, invoked separately, not part of `#env` |

## Running

```bash
# Desktop (needs a clean tty — greetd or login, not from inside another session)
nix run github:solokha/wrapps#desktop

# Shell
nix run github:solokha/wrapps#env      # same as #shell / #denv
nix run github:solokha/wrapps#shell

# A single package
nix run github:solokha/wrapps#foot
```

From a local clone — `nix run .#env`, offline.

## Using it with NixOS

Add the flake as an input; the overlay exposes the packages in `pkgs`:

```nix
inputs.wrapps.url = "github:solokha/wrapps/dev";
nixpkgs.overlays = [ inputs.wrapps.overlays.default ];
inputs.wrapps.nixosModules.desktop
```

The `dev` branch is required — `main` is empty.

## Keys

`#env` starts its own `ssh-agent` and works with FIDO2 keys in a graphical
session. Two commands are on the shell's PATH: `wrapps-agent` and
`wrapps-ssh-config`.

```bash
# once: restore resident keys from the token
cd ~/.ssh && ssh-keygen -K

# inside a session the agent is already running
eval "$(wrapps-agent)"
wrapps-ssh-config
ssh -T git@github.com
```

Details about FIDO2, keystore, and DR procedures live in the private `infra`
documentation (`docs/wrapps-input.md`, `docs/rollback-keystore.md`).
