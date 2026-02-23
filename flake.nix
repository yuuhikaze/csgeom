{
  description = "Computational Geometry Algorithms - Visualizations with SDL3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}.master;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            zig
            pkgs.sdl3
          ];

          shellHook = ''
            echo "====== Computational Geometry Environment ======"
            echo '                             ('
            echo '            RAAAAaaaaaahh!'
            echo '                         (   ()   )'
            echo '               ) ________    //  )'
            echo '            ()  |\       \  //'
            echo '           ( \\__ \ ______\//'
            echo '              \__) | _  _  |'
            echo '                |  | ^--^  |'
            echo '                 \ |  \/   |'
            echo '                  \|_______|'
            echo '                  //    \\'
            echo '                 ((     ||'
            echo '                  \\    ||'
            echo '                ( ()    ||'
            echo '                 (      () ) )'
            echo "Zig: $(zig version)"
            echo "================================================"
          '';
        };
      }
    );
}
