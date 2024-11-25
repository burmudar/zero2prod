{ pkgs, lib, buildLayeredImage, crate }:
let
  files = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./src
      ./migrations
      ./configuration
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
      Env = [
        "APP_ENVIRONMENT=production"
        "SQLX_OFFLINE=true"
      ];
      Entrypoint = [ "${crate}/bin/zero2prod" ];
    };
}
