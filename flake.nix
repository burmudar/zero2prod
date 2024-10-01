{
  description = "flake for rust development";

  # Nixpkgs / NixOS version to use.
  inputs= {
    nixpkgs.url = "github:NixOS/nixpkgs";
    unstable-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable-nixpkgs, crane, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };
      uPkgs = import unstable-nixpkgs {
        inherit system;
      };
      rustVersion = "1.81.0";
      craneLib = (crane.mkLib pkgs).overrideToolchain (p: p.rust-bin.stable."${rustVersion}");

      sqlFilter = path: _type: null != builtins.match ".*sql$" path;
      sqlOrCargo = path: type: (sqlFilter path type) || (craneLib.filterCargoSource path type);
      src = craneLib.cleanCargoSource {
        src = ./.;
        filter = sqlOrCargo;
        name = "source";
      };

      commonArgs = {
        inherit src;
        strictDeps = true;

        nativeBuildInputs = [
            pkgs.pkg-config
        ];

          buildInputs = [
            pkgs.postgresql_16
            pkgs.openssl
            pkgs.glibc.dev
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          ];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      zero2prod = craneLib.buildPackage ( commonArgs // {
          inherit cargoArtifacts;

          nativeBuildInputs = (commonArgs.nativeBuildInputs or []) ++ [ pkgs.sqlx-cli ];
          preBuild = ''
            ./start-db.sh
          '';
        });

    in
    {

      checks = {
          inherit zero2prod;
      };

      packages = {
          default = zero2prod;
          inherit zero2prod;
        };
      formatter = pkgs.nixpkgs-fmt;

      # Add dependencies that are only needed for development
      devShells =
        {
          default = pkgs.mkShell ( commonArgs // {
            buildInputs = (commonArgs.buildInputs or []) ++ [
              # we install this here instaed of cargo ... since installing binaries with cargo results in glibc issues
              uPkgs.sqlx-cli
              uPkgs.bunyan-rs
            ];

            # need to tell pkg_config where to find openssl hence PKG_CONFIG_PATH
            shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
            export PATH="$HOME/.cargo/bin":$PATH


            # initialize services needed in our shell
            . ./dev/shell-hook.sh
            '';
          });


        };
      });
}
