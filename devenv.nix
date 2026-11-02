{pkgs, ...}: {
  languages.rust = {
    enable = true;
    # rustup reads the same file outside Nix.
    toolchainFile = ./rust-toolchain.toml;
  };

  packages = [
    pkgs.git
    pkgs.openssl
    pkgs.pkg-config
    pkgs.cargo-deny
    pkgs.cargo-nextest
    pkgs.cargo-edit
    pkgs.bacon
  ];
}
