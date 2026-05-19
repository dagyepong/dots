{
  self,
  pkgs,
  ...
}:
let
  fakeDms = pkgs.writeShellScriptBin "hype" ''
    printf '%s\n' "$@" > /tmp/hype-service-args
    exec ${pkgs.coreutils}/bin/sleep 300
  '';
in
pkgs.testers.runNixOSTest {
  name = "hype-nixos-service-start-module";

  nodes.machine = {
    imports = [
      self.nixosModules.hype-material-shell
    ];

    users.users.hypelinux = {
      isNormalUser = true;
      linger = true;
      extraGroups = [ "wheel" ];
    };

    programs.hype-material-shell = {
      enable = true;
      package = fakeDms;
      systemd = {
        enable = true;
        target = "default.target";
      };
    };

    system.stateVersion = "25.11";
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")

    machine.succeed("systemctl --machine=hypelinux@ --user start hype.service")
    machine.wait_until_succeeds("systemctl --machine=hypelinux@ --user is-active hype.service")
    machine.wait_until_succeeds("test -f /tmp/hype-service-args")
    machine.succeed("grep -Fx run /tmp/hype-service-args")
    machine.succeed("grep -Fx -- --session /tmp/hype-service-args")
  '';
}
