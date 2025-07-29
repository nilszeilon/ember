{
  description = "Phoenix 1.8 Elixir project with dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        beamPackages = pkgs.beam.packages.erlang_26;

        # Elixir 1.16.2 is latest stable, compatible with Phoenix 1.8 RCs
        elixir = pkgs.elixir_1_16;

        # Needed for Phoenix 1.8
        devDeps = with pkgs; [
          beamPackages.erlang
          elixir
          nodejs_20
          postgresql
          inotify-tools
          esbuild
          tailwindcss
          openssl
          pkg-config
          # if you need image processing:
          imagemagick
        ];

      in {
        devShells.default = pkgs.mkShell {
          buildInputs = devDeps;

          # Needed for some Elixir/OTP native deps (like bcrypt_elixir)
          shellHook = ''
            export MIX_ENV=dev
            export ERL_AFLAGS="-kernel shell_history enabled"
            export PATH="$PWD/assets/node_modules/.bin:$PATH"
            echo "🚀 Ready: Phoenix 1.8 RC dev shell"
          '';
        };
      });
}

