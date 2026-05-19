{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [
        "programs"
        "hypeMaterialShell"
      ]
      [
        "programs"
        "hype-material-shell"
      ]
    )
  ];
}
