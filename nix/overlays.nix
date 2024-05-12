self: final: super: {
  pythonPackagesOverlays =
    (super.pythonPackagesOverlays or [])
    ++ [
      (_: pprev: {
        pywlroots = (pprev.pywlroots.overrideAttrs(_: rec {
          version = "0.17.0";
          src = super.fetchFromGitHub {
            owner = "jwijenbergh";
            repo = "pywlroots";
            rev = "13a4fb3c9aa6f6c6f0d2f6fe496fa2bfbeb3d656";
            hash = "sha256-q0sQA4HyoMOlYG/eJZZRW1PokX716m7pDbwtxRUMt4Y=";
          };
        })).override {
          wlroots = super.wlroots_0_17;
        };
        qtile = (pprev.qtile.overrideAttrs (old: let
          flakever = self.shortRev or "dev";
        in {
          version = "0.0.0+${flakever}.flake";
          # use the source of the git repo
          src = ./..;
          # for qtile migrate, not in nixpkgs yet
          propagatedBuildInputs = old.propagatedBuildInputs ++ [ pprev.libcst ];
        })).override {
          wlroots = super.wlroots_0_17;
        };
      })
    ];
  python3 = let
    self = super.python3.override {
      inherit self;
      packageOverrides = super.lib.composeManyExtensions final.pythonPackagesOverlays;
    };
  in
    self;
  python3Packages = final.python3.pkgs;
}


