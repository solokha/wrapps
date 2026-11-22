{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.starship.wrap {
  inherit pkgs;

  settings = {
    "$schema" = "https://starship.rs/config-schema.json";

    time = {
      disabled = false;
      format = "15:04";
    };

    username.format = " [$user]($style)";

    hostname = {
      ssh_only = false;
      format = "[@]($style) ";
      style = "hostname";
    };

    directory = {
      truncation_length = 3;
      truncate_to_repo = true;
      style = "path";
    };

    nix_shell = {
      symbol = "nix";
      style = "nix_shell";
    };

    git_branch = {
      symbol = " ";
      style = "branch";
      format = "[$symbol$branch]($style) ";
    };

    git_status = {
      style = "git";
      format = "([$all_status$ahead_behind]($style) )";
      conflicted = "=";
      ahead = "⇡\${count}";
      behind = "⇣\${count}";
      diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
      untracked = "?\${count}";
      stashed = "$\${count}";
      modified = "!\${count}";
      staged = "+\${count}";
      renamed = "»\${count}";
      deleted = "✗\${count}";
    };

    character = {
      success_symbol = "[❯](bold green)";
      error_symbol = "[❯](bold red)";
      vicmd_symbol = "[❮](bold yellow)";
    };
  };

  runShell = [
    ''
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
      if [ ! -f "$cfg" ]; then
        mkdir -p "$(dirname "$cfg")"
        install -m 644 ${builtins.placeholder "out"}/starship.toml "$cfg"
      fi
      export STARSHIP_CONFIG="$cfg"
    ''
  ];
}
