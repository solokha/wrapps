{inputs}: final: prev: let
  system = final.stdenv.hostPlatform.system;

  # llm-agents собирает свои пакеты против final, а не против своего nixpkgs:
  # closure совпадает с системой потребителя. Кэш cache.numtide.com попадает
  # только при совпадении ревизий nixpkgs — ради этого и follows на входе.
  llm-agents = (inputs.llm-agents.overlays.shared-nixpkgs final prev).llm-agents;
in {
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  master = import inputs.nixpkgs-master {
    inherit system;
    config.allowUnfree = true;
  };
  # Пакеты llm-agents под своим именем: pkgs.llm-agents.opencode2 и т. д.
  inherit llm-agents;
  wrapps = {
    zellij = inputs.self.packages.${system}.zellij;
    helix = inputs.self.packages.${system}.helix;
    nh = inputs.self.packages.${system}.nh;
    opencode = inputs.self.packages.${system}.opencode;
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
