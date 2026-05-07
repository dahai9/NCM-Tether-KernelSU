{
  description = "Rust uevent listener for NCM Tether";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
        ndk = pkgs.androidenv.androidPkgs.ndk-bundle;
        rustVersion = pkgs.rust-bin.stable.latest.default.override {
          targets = [ "aarch64-linux-android" ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rustVersion
            pkgs.cargo-ndk
            ndk
            pkgs.zip
          ];
          shellHook = ''
            export ANDROID_NDK_HOME=${ndk}/libexec/android-sdk/ndk-bundle
          '';
        };
      }
    );
}
