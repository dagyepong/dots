{
  self,
  pkgs,
  ...
}:
let
  homeManagerNixosModule =
    (fetchTarball {
      url = "https://github.com/nix-community/home-manager/archive/e82d4a4ecd18363aa2054cbaa3e32e4134c3dbf4.tar.gz";
      sha256 = "sha256-ZTYDofOM3/PJhRF1EuBh6uibm+DmkhU7Wor6mMN7YTc=";
    })
    + "/nixos";

  niriFlake = builtins.getFlake "github:sodiboo/niri-flake/2bb22af2985e5f3cfd051b3d977ebfbf81126280?narHash=sha256-ooPmu%2B8tqOGh4kozPW4rJC7Y7WM/FHtEY3OK1PoNW7g%3D";

  fakeNiri = (pkgs.writeScriptBin "niri" "") // {
    cargoBuildNoDefaultFeatures = false;
  };
in
pkgs.testers.runNixOSTest {
  name = "hype-niri-home-module";

  nodes.machine = {
    ...
  }: {
    imports = [
      homeManagerNixosModule
    ];

    users.users.hypelinux = {
      isNormalUser = true;
      createHome = true;
      home = "/home/hypelinux";
      extraGroups = [ "wheel" ];
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;

    environment.pathsToLink = [
      "/share/applications"
      "/share/xdg-desktop-portal"
    ];

    home-manager.users.hypelinux = {
      ...
    }: {
      imports = [
        self.homeModules.hype-material-shell
        niriFlake.homeModules.niri
        self.homeModules.niri
      ];

      home.username = "hypelinux";
      home.homeDirectory = "/home/hypelinux";
      home.stateVersion = "25.11";

      programs.niri = {
        enable = true;
        package = fakeNiri; # avoids niri from being compiled in the CI
      };

      programs.hype-material-shell = {
        enable = true;
        niri = {
          enableKeybinds = false;
          enableSpawn = true;
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.succeed("su -- hypelinux -c 'test -f ~/.config/niri/config.kdl'")
    machine.succeed("su -- hypelinux -c 'grep -F \"include \\\"hype/binds.kdl\\\"\" ~/.config/niri/config.kdl'")
    machine.succeed("su -- hypelinux -c 'grep -F \"include \\\"hm.kdl\\\"\" ~/.config/niri/config.kdl'")
    machine.succeed("su -- hypelinux -c 'grep -F \"spawn-at-startup\" ~/.config/niri/hm.kdl'")
    machine.succeed("su -- hypelinux -c 'grep -F \"\\\"hype\\\" \\\"run\\\"\" ~/.config/niri/hm.kdl'")
  '';
}
