{ pkgs, lib, buildLayeredImage, crate }:
let
  files = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
      ./migrations
      ./configuration.yaml
    ];
  };
in
  buildLayeredImage {
    name = "zero2prod";
    tag = "latest";
    contents = [
      pkgs.bashInteractive pkgs.coreutils "${crate}" files
    ];
    config = {
      Entrypoint = [ "${crate}/bin/zero2prod" ];
    };
}
