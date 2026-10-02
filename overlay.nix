{ inputs }:
final: prev:
let
  system = final.stdenv.hostPlatform.system;
in {
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  wrapps = {
    zellij   = inputs.self.packages.${system}.zellij;
    helix    = inputs.self.packages.${system}.helix;
    nh       = inputs.self.packages.${system}.nh;
    foot     = inputs.self.packages.${system}.foot;
    fuzzel   = inputs.self.packages.${system}.fuzzel;
    zed      = inputs.self.packages.${system}.zed;
    niri     = inputs.self.packages.${system}.niri;
    firefox  = inputs.self.packages.${system}.firefox;
    noctalia = inputs.self.packages.${system}.noctalia;
    nixos-anywhere = inputs.self.packages.${system}.nixos-anywhere;
  };
  inherit (inputs.self.packages.${system}) env desktop;
}
