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
          baseDeps = with pkgs; [
            # define your own version here
            rust-bin.stable."${rustVersion}".default
            rust-bin.stable."${rustVersion}".rustfmt
            rust-bin.stable."${rustVersion}".rust-analyzer
          ];
        in
        {
          default = pkgs.mkShell {
            buildInputs = baseDeps;
          };
        });

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixpkgs-fmt);

    };
}
