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
            rev = "52a147aed8b9860221a4e2b91da3b680b8497261";
            hash = "sha256-wb5TUVvXz8M6ytOpmr9Jvq+4CCQAZ72rTE+Kqae4heo=";
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


