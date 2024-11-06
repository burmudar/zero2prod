{ pkgs, buildImage, crate }:
  buildImage {
    name = "zero2prod";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      # TODO: Look at https://nixos.org/manual/nixpkgs/unstable/#function-library-lib.fileset.toSource to create a drv with the source, since we can't directly include a single file like we currenlty doing
      paths = [ pkgs.bashInteractive pkgs.coreutils "${crate}" ./. ];
      pathsToLink = [ "/bin" "/src" "/migrations" ./configuration.yaml ];
    };
    config = {
      Entrypoint = [ "${pkgs.bashInteractive}/bin/bash" ];
    };
}
