{inputs}: final: prev: let
  system = final.stdenv.hostPlatform.system;

  llm-agents = (inputs.llm-agents.overlays.shared-nixpkgs final prev).llm-agents;
in {
  master = import inputs.nixpkgs-master {
    inherit system;
    config.allowUnfree = true;
  };
  inherit llm-agents;
  wrapps = {
    opencode = inputs.self.packages.${system}.opencode;
    atuin = inputs.self.packages.${system}.atuin;
    btop = inputs.self.packages.${system}.btop;
    starship = inputs.self.packages.${system}.starship;
    tmux = inputs.self.packages.${system}.tmux;
    foot = inputs.self.packages.${system}.foot;
    fuzzel = inputs.self.packages.${system}.fuzzel;
    zed = inputs.self.packages.${system}.zed;
    niri = inputs.self.packages.${system}.niri;
    firefox = inputs.self.packages.${system}.firefox;
    noctalia = inputs.self.packages.${system}.noctalia;
    nixos-anywhere = inputs.self.packages.${system}.nixos-anywhere;
  };
  inherit (inputs.self.packages.${system}) env desktop;
}
