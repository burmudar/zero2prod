{
  description = "flake for rust development";

  # Nixpkgs / NixOS version to use.
  inputs= {
    nixpkgs.url = "github:NixOS/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay }:
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
      });
      rustVersion = "1.81.0";

    in
    {

      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let
          pkgs = let result = nixpkgsFor.${system}; in result.pkgs;
          rust = pkgs.rust-bin.stable."${rustVersion}";
          baseDeps = [
            rust.default
            rust.rustfmt
            rust.rust-analyzer
            rust.clippy

            # other dependencies
            pkgs.openssl
            pkgs.postgresql_16
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

            if ! [ -x "$(command -v sqlx)" ]; then
              cargo install --version 0.8.2 sqlx-cli --no-default-features --features postgres
            fi

            # initialize services needed in our shell
            . ./dev/shell-hook.sh
            '';
          };
        });

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);

    };
}
