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
in
pkgs.testers.runNixOSTest {
  name = "hype-home-manager-module";

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

    home-manager.users.hypelinux = {
      pkgs,
      ...
    }: {
      imports = [
        self.homeModules.hype-material-shell
      ];

      home.username = "hypelinux";
      home.homeDirectory = "/home/hypelinux";
      home.stateVersion = "25.11";

      programs.hype-material-shell = {
        enable = true;
        systemd = {
          enable = true;
          target = "default.target";
        };

        settings = {
          theme = "integration-test";
        };

        clipboardSettings = {
          maxItems = 10;
        };

        session = {
          startedFrom = "nixos-test";
        };

        plugins.TestPlugin = {
          enable = true;
          src = pkgs.runCommand "hype-test-plugin" { } ''
            mkdir -p "$out"
            echo plugin > "$out/plugin.txt"
          '';
          settings = {
            enabled = true;
            source = "test";
          };
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    machine.succeed("su -- hypelinux -c 'command -v hype'")
    machine.succeed("su -- hypelinux -c 'test -f ~/.config/HypeMaterialShell/settings.json'")
    machine.succeed("su -- hypelinux -c 'test -f ~/.config/HypeMaterialShell/clsettings.json'")
    machine.succeed("su -- hypelinux -c 'test -f ~/.config/HypeMaterialShell/plugin_settings.json'")
    machine.succeed("su -- hypelinux -c 'test -e ~/.config/HypeMaterialShell/plugins/TestPlugin'")
    machine.succeed("su -- hypelinux -c 'test -f ~/.local/state/HypeMaterialShell/session.json'")

    settings = json.loads(machine.succeed("su -- hypelinux -c 'cat ~/.config/HypeMaterialShell/settings.json'"))
    clipboard = json.loads(machine.succeed("su -- hypelinux -c 'cat ~/.config/HypeMaterialShell/clsettings.json'"))
    session = json.loads(machine.succeed("su -- hypelinux -c 'cat ~/.local/state/HypeMaterialShell/session.json'"))
    plugins = json.loads(machine.succeed("su -- hypelinux -c 'cat ~/.config/HypeMaterialShell/plugin_settings.json'"))
    doctor = json.loads(machine.succeed("su -- hypelinux -c 'hype doctor --json'"))

    t.assertEqual(settings["theme"], "integration-test")
    t.assertEqual(clipboard["maxItems"], 10)
    t.assertEqual(session["startedFrom"], "nixos-test")
    t.assertTrue(plugins["TestPlugin"]["enabled"])
    t.assertEqual(plugins["TestPlugin"]["source"], "test")
    t.assertIsInstance(doctor.get("results"), list)
  '';
}
