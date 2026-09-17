#!/bin/sh
set -e

CONFIG_DIR="$HOME/.config/noctalia"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.toml" ]; then
  cp ${config} "$CONFIG_DIR/config.toml"
fi

noctalia-shell &
