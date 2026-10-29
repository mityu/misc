{
  description = "casty - TTY web browser using raw CDP and Kitty graphics protocol";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    casty-src = {
      url = "github:sanohiro/casty";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      casty-src,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib;

          # casty itself, without a bundled browser. It will try to download
          # Chrome Headless Shell into ~/.casty/browsers/ on first run.
          casty-unwrapped = pkgs.buildNpmPackage {
            pname = "casty";
            version = (lib.importJSON "${casty-src}/package.json").version;
            src = casty-src;

            # Upstream does not ship a lock file.
            postPatch = ''
              cp ${./package-lock.json} package-lock.json
            '';

            npmDepsHash = "sha256-XBtQc+VmEAoDDGcDW5Y+Xfwl2YALlZoxNQeuQVHNPnY=";
            npmFlags = [ "--ignore-scripts" ];
            dontNpmBuild = true;

            meta = {
              description = "TTY web browser using raw CDP and Kitty graphics protocol";
              homepage = "https://github.com/sanohiro/casty";
              license = lib.licenses.mit;
              mainProgram = "casty";
            };
          };

          # nixpkgs has no standalone chrome-headless-shell, so emulate one
          # with Chromium in headless mode.
          headless-shell = pkgs.writeShellScriptBin "chromium-headless-shell" ''
            exec ${lib.getExe pkgs.chromium} --headless "$@"
          '';

          # casty using the Nix-provided headless shell. A --headless-shell given
          # on the command line still takes precedence (the last one wins).
          casty = pkgs.symlinkJoin {
            name = "casty-${casty-unwrapped.version}";
            paths = [ casty-unwrapped ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/casty \
                --add-flags "--headless-shell ${lib.getExe headless-shell}"
            '';
            inherit (casty-unwrapped) meta;
          };
        in
        {
          inherit casty-unwrapped;
        }
        // lib.optionalAttrs (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.chromium) {
          inherit casty headless-shell;
          default = casty;
        }
        // lib.optionalAttrs (!lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.chromium) {
          default = casty-unwrapped;
        }
      );

      apps = forAllSystems (
        pkgs:
        let
          # Regenerate package-lock.json from the locked casty-src and update
          # npmDepsHash to match. Run it from the flake's root directory.
          update-lock = pkgs.writeShellApplication {
            name = "update-lock";
            runtimeInputs = [
              pkgs.nodejs
              pkgs.prefetch-npm-deps
              pkgs.gnused
            ];
            text = ''
              if [ ! -f flake.nix ]; then
                echo "update-lock: run this from the flake's root directory" >&2
                exit 1
              fi

              tmp=$(mktemp -d)
              trap 'rm -rf "$tmp"' EXIT

              cp ${casty-src}/package.json "$tmp/"
              chmod u+w "$tmp/package.json"
              npm install --prefix "$tmp" --package-lock-only --ignore-scripts --no-audit --no-fund
              cp "$tmp/package-lock.json" package-lock.json

              hash=$(prefetch-npm-deps package-lock.json)
              sed -i "s|npmDepsHash = \"[^\"]*\";|npmDepsHash = \"$hash\";|" flake.nix
              echo "update-lock: npmDepsHash = $hash"
            '';
          };
        in
        {
          default = {
            type = "app";
            program = nixpkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.default;
            meta.description = "Run casty";
          };
          update-lock = {
            type = "app";
            program = nixpkgs.lib.getExe update-lock;
            meta.description = "Regenerate package-lock.json and npmDepsHash";
          };
        }
      );
    };
}
