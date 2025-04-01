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
        # Set to 1 to enable debuig options
        DEBUG = 1;
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        inherit (pkgs) lib;

        upkgs = import unstable-nixpkgs {
          inherit system;
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain pkgs.rust-bin.stable."1.81.0".default;

        miscFileFilter = path: _type: null != builtins.match ".*sql$|.*sh$|.*yaml$|^.sqlx$|.*json$" path;
        sqlOrCargo = path: type: (miscFileFilter path type) || (craneLib.filterCargoSources path type);
        # Use lib.sources.trace to see what the filter below filters
        src = lib.cleanSourceWith {
          src = if DEBUG == 1 then lib.sources.trace (craneLib.path ./.) else (craneLib.path ./.);
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
        # careful where you put this preBuild. If you put it CommonArgs it will apply to
        # craneLib.buildDepsOnly too - which is a much more strict env with only rust files available
        preBuild = ''
          . dev/shell-hook.sh
        '';
        cargoArtifacts = craneLib.buildDepsOnly (commonArgs);

        # Build the actual Rust package
        # this actually builds the package with `--release`
        zero2prod = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
          # TODO(burmudar): If this is set, .sqlx, should be present in the sources, but it isn't
          # we should debug our miscFilter
          SQLX_OFFLINE = true;
          # # we need the DB to be up before things are built
          # inherit preBuild;
        });

        # we technically don't need this since our package gets compiled locally via nix
        # thus the db will be available at compile time. This is mostly just done for
        # educational purposes
        sqlx-offline = craneLib.buildPackage ( commonArgs // {
          inherit cargoArtifacts;
          inherit preBuild;
          pname = "sqlx-offline";
          doCheck = false;
          buildPhaseCargoCommand = "cargo sqlx prepare -- --lib";
          installPhaseCommand = "mkdir -p $out && cp -Rv .sqlx $out/ && ls -la $out;";
        });

        copy-sqlx-offline = pkgs.writeScriptBin "copy-sqlx-offline" ''
            #!/usr/bin/env bash
            mkdir -p .sqlx
            cp -Rv ${sqlx-offline}/.sqlx/* .sqlx
        '';

      in
      {

        checks = {
          default = zero2prod;
          inherit zero2prod;

          zero2prod-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            # we need the DB to be up before things are built
            inherit preBuild;
            cargoClippyExtraArgs = "-- -D warnings";
          });
        };

        packages = {
          inherit copy-sqlx-offline;
          default = zero2prod;
          sqlx-offline = sqlx-offline;
          docker = (pkgs.callPackage ./docker.nix {inherit pkgs; buildLayeredImage = pkgs.dockerTools.buildLayeredImage; crate = zero2prod;});
        };

        apps = {
          offline = {
            type = "app";
            program = "${self.packages.${system}.copy-sqlx-offline}/bin/copy-sqlx-offline";
          };
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
