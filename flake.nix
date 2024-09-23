{
  description = "flake for rust development";

  # Nixpkgs / NixOS version to use.
  inputs= {
    nixpkgs.url = "github:NixOS/nixpkgs";
    unstable-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, unstable-nixpkgs, rust-overlay }:
    let

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            rust-overlay.overlays.default
          ];
        };
        unstablePkgs = import unstable-nixpkgs {
          inherit system;
        };
      });
      rustVersion = "1.81.0";

    in
    {

      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let
          pkgs = let result = nixpkgsFor.${system}; in result.pkgs;
          uPkgs = let result = nixpkgsFor.${system}; in result.unstablePkgs;
          rust = pkgs.rust-bin.stable."${rustVersion}";
          rust-nightly = pkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
          baseDeps = [
            rust-nightly
            rust.rustfmt
            rust.rust-analyzer
            rust.clippy

            # we install this here instaed of cargo ... since installing binaries with cargo results in glibc issues
            uPkgs.sqlx-cli

            # other dependencies
            pkgs.openssl
            pkgs.postgresql_16
            pkgs.glibc.dev
          ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
            pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
          ];
        in
        {
          default = pkgs.mkShell {
            buildInputs = baseDeps;
            nativeBuildInputs = [ pkgs.pkg-config ]; # need this for openssl-sys crate
            # need to tell pkg_config where to find openssl hence PKG_CONFIG_PATH
            shellHook = ''
            export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig";
            export PATH="$HOME/.cargo/bin":$PATH


            # initialize services needed in our shell
            . ./dev/shell-hook.sh
            '';
          };
        });

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);

    };
}
