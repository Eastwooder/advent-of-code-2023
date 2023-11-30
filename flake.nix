{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };
  outputs = { self, nixpkgs, flake-utils, rust-overlay, crane, pre-commit-hooks }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          overlays = [ (import rust-overlay) ];
          pkgs = import nixpkgs {
            inherit system overlays;
          };

          # import and bind toolchain to the provided `rust-toolchain.toml` in the root directory
          rustToolchain = pkgs.pkgsBuildHost.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;

          craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

          # declare the sources
          src = pkgs.lib.cleanSourceWith {
            src = ./.;
            filter = path: type:
              # include everything in the `tests` directory - including test objects
              (pkgs.lib.hasInfix "/tests/" path) ||
              # Default filter from crane (allow .rs files)
              (craneLib.filterCargoSources path type)
            ;
          };

          # declare the build inputs used to build the projects
          nativeBuildInputs = with pkgs; [
            rustToolchain
            pkg-config
          ] ++ macosBuildInputs;
          # declare the build inputs used to link and run the projects, will be included in the final artifact container
          buildInputs = with pkgs; [ openssl sqlite ];
          macosBuildInputs = with pkgs.darwin.apple_sdk.frameworks;
            [ ]
            ++ (nixpkgs.lib.optionals (nixpkgs.lib.hasSuffix "-darwin" system) [
              Security
              CoreFoundation
            ]);

          # declare build arguments
          commonArgs = {
            inherit src buildInputs nativeBuildInputs;
          };

          # Cargo artifact dependency output
          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          aoc = craneLib.buildPackage (commonArgs // {
            inherit cargoArtifacts;
            pname = "advent-of-code-2023";
          });
        in
        with pkgs;
        {
          # formatter for the flake.nix
          formatter = nixpkgs-fmt;

          # executes all checks
          checks = {
            inherit aoc;
            aoc-clippy = craneLib.cargoClippy (commonArgs // {
              inherit cargoArtifacts;
              cargoClippyExtraArgs = "--all-targets";
            });
            aoc-fmt = craneLib.cargoFmt commonArgs;
            # pre-commit-checks to be installed for the dev environment
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              src = ./.;
              # git commit hooks
              hooks = {
                nixpkgs-fmt.enable = true;
                # clippy.enable = true;
                rustfmt.enable = true;
                markdownlint.enable = true;
                commitizen.enable = true;
                typos.enable = true;
              };
            };
          };

          # packages to build and provide
          packages = {
            inherit aoc;
            default = aoc;
          };

          # applications which can be started as-is
          apps.aoc = {
            type = "app";
            program = "${self.packages.${system}.aoc}/bin/advent-of-code-2023";
          };

          # development environment provided with all bells and whistles included
          devShells.default = mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            inputsFrom = [
              aoc
            ];
            buildInputs = with pkgs; [
              act
              aoc-cli
            ];
          };
        });
}
