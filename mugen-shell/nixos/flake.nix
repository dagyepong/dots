{
  description = "mugen-shell NixOS umbrella — system-level integration on top of the user-level flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The user-level flake (homeManagerModules + packages + overlays).
    # `path:..` resolves to the repo root when this flake is fetched via
    # `?dir=nixos`; using a relative path keeps the two layers in lock-step.
    mugen-shell = {
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      mugen-shell,
      ...
    }:
    let
      # The NixOS module body lives in the parent repo so the layout is one
      # source of truth; we just wrap it in an overlay-applying shim here.
      overlay = mugen-shell.overlays.default;
      nixosModule =
        { ... }:
        {
          imports = [ ./module.nix ];
          nixpkgs.overlays = [ overlay ];
        };
    in
    {
      nixosModules.default = nixosModule;
      nixosModules.mugen-shell = nixosModule;

      # Re-export user-level surface so a NixOS user only needs one flake
      # input — they can still pull homeManagerModules / packages from here.
      inherit (mugen-shell)
        packages
        homeManagerModules
        overlays
        ;
    };
}
