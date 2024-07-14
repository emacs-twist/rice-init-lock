{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";

    emacs-ci.url = "github:purcell/nix-emacs-ci";
    twist.url = "github:emacs-twist/twist.nix";

    # Inputs that should be overridden for each project.
    rice-src.url = "github:emacs-twist/rice-config?dir=example";
    # If your project depends only on built-in packages, you don't have to
    # override this. Also see https://github.com/NixOS/nix/issues/9339
    rice-lock.url = "github:emacs-twist/rice-config?dir=lock";

    emacs-builtins.url = "github:emacs-twist/emacs-builtins";

    registries.url = "github:emacs-twist/registries";
    registries.inputs.melpa.follows = "melpa";

    melpa.url = "github:melpa/melpa";
    melpa.flake = false;
  };

  outputs = {
    systems,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;

    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system: let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              inputs.twist.overlays.default
            ];
          };
        in
          f pkgs
      );

    localPackages = inputs.rice-src.elisp-rice.packages;

    emacsEnvWith = {pkgs}: emacsPackage:
      pkgs.emacsTwist {
        inherit emacsPackage;
        nativeCompileAheadDefault = false;
        initFiles = [];
        extraPackages = localPackages;
        initialLibraries =
          inputs.emacs-builtins.lib.builtinLibrariesOfEmacsVersion
          emacsPackage.version;
        registries = inputs.registries.lib.registries;
        lockDir = inputs.rice-lock.outPath;
        inherit localPackages;
        inputOverrides = lib.genAttrs localPackages (_: {
          src = inputs.rice-src.outPath;
          mainIsAscii = true;
        });
        exportManifest = false;
      };
  in {
    packages = eachSystem (
      pkgs:
        lib.mapAttrs' (
          emacsName: emacsPackage:
            lib.nameValuePair "lock-with-${emacsName}"
            (emacsEnvWith {inherit pkgs;} emacsPackage).generateLockDir
        )
        inputs.emacs-ci.packages.${pkgs.system}
    );
  };
}
