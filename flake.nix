{
  description = "agents-retro development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    moonbit-overlay.url = "github:moonbit-community/moonbit-overlay";
  };

  outputs =
    {
      nixpkgs,
      moonbit-overlay,
      ...
    }:
    let
      # moonbit-overlay publishes toolchain binaries only for these platforms.
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ moonbit-overlay.overlays.default ];
        };
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.moonbit-bin.latest
              pkgs.lefthook
              pkgs.actionlint
            ];
          };
        }
      );

      formatter = forAllSystems (system: (mkPkgs system).nixfmt);
    };
}
