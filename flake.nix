{
  description = "flake for rust development";

  # Nixpkgs / NixOS version to use.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    unstable-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      # if you specify just nixpkgs.follows, then you'll get a confusing infinite branching error
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, unstable-nixpkgs, crane, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        inherit (pkgs) lib;

        upkgs = import unstable-nixpkgs {
          inherit system;
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain pkgs.rust-bin.stable."1.81.0".default;

        miscFileFilter = path: _type: null != builtins.match ".*sql$|.*sh$|.*yaml$" path;
        sqlOrCargo = path: type: (miscFileFilter path type) || (craneLib.filterCargoSources path type);
        # Use lib.sources.trace to see what the filter below filters
        src = lib.cleanSourceWith {
          src = craneLib.path ./.;
          filter = sqlOrCargo;
          name = "source";
        };


        commonArgs = {
          inherit src;
          strictDeps = true;

          nativeBuildInputs = [
            pkgs.pkg-config
            upkgs.sqlx-cli
            pkgs.postgresql_16
          ];

          buildInputs = [
            pkgs.openssl
            pkgs.glibc.dev
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          ];
        };
        preBuild = ''
          . dev/shell-hook.sh
        '';
        cargoArtifacts = craneLib.buildDepsOnly (commonArgs);

        # Build the actual Rust package
        zero2prod = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          inherit preBuild;

          # careful where you put this preBuild. If you put it CommonArgs it will apply to
          # craneLib.buildDepsOnly too - which is a much more strict env with only rust files available

        });

      in
      {

        checks = {
          default = zero2prod;
          inherit zero2prod;

          zero2prod-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            inherit preBuild;
            cargoClippyExtraArgs = "-- -D warnings";
          });
        };

        packages = {
          default = zero2prod;
        };

        formatter = pkgs.nixpkgs-fmt;

        devShells.default = craneLib.devShell (commonArgs // {
          packages = (commonArgs.nativeBuildInputs or [ ]) ++ (commonArgs.buildInputs or [ ]) ++ [
            pkgs.rust-analyzer
            # we install this here instaed of cargo ... since installing binaries with cargo results in glibc issues
            upkgs.sqlx-cli
            upkgs.bunyan-rs
          ];

          # need to tell pkg_config where to find openssl hence PKG_CONFIG_PATH
          shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
            export PATH="$HOME/.cargo/bin":$PATH


            # initialize services needed in our shell
            . ./dev/shell-hook.sh
          '';
        });
      });
}
