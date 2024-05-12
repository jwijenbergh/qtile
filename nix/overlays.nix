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
            rev = "2b4919bf938e481b8db283d935a028e5ed55138d";
            hash = "sha256-lHT9TMnhN546Icub9PsepDePAJ2353a9lPjiNRUz1Vw=";
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


