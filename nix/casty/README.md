Nix package definition for [casty](https://github.com/sanohiro/casty).

- To run casty, run `nix run .`
- To build casty, run `nix build .`
- To update lock files, run `nix run .#update-lock`
    - This updates not only the `flake.lock`, but also the `package-lock.json`.
    - Since the casty repository doesn't ship `package-lock.json`, we need to maintain it here too.
