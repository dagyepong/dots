{
  self,
  pkgs,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "hype-nixos-module";

  nodes.machine = {
    imports = [
      self.nixosModules.hype-material-shell
    ];

    users.users.hypelinux = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };

    programs.hype-material-shell = {
      enable = true;
      systemd.enable = true;
      plugins = {
        TestPlugin = {
          src = pkgs.emptyDirectory;
        };
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    import json

    machine.wait_for_unit("multi-user.target")

    machine.succeed("command -v hype")
    machine.succeed("command -v quickshell")
    machine.succeed("su -- hypelinux -c 'hype --help >/dev/null'")
    machine.succeed("test -d /etc/xdg/quickshell/hype-plugins")
    machine.succeed("test -f /run/current-system/sw/lib/systemd/user/hype.service")

    payload = json.loads(machine.succeed("su -- hypelinux -c 'hype doctor --json'"))
    t.assertIn("summary", payload)
    t.assertIsInstance(payload.get("results"), list)
  '';
}
