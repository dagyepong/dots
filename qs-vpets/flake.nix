{
  description = "Desktop virtual pets for Hyprland/Wayland via Quickshell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      forAllSystems =
        fn: nixpkgs.lib.genAttrs nixpkgs.lib.platforms.linux (system: fn nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        qs-vpets = pkgs.callPackage ./nix {
          quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
            withX11 = false;
            withI3 = false;
          };
        };
        default = qs-vpets;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
          ];

          shellHook = ''
            echo "--------------------------------------------"
            echo "qs-vpets Development Environment"
            echo "  Run:  qs -p ."
            echo "  Exit: Ctrl-D"
            echo "--------------------------------------------"

            export QS_DEBUG=1
            alias qsr="qs -p ."
          '';
        };
      });

      homeManagerModules.default = import ./nix/hm-module.nix self;
    };
}
