self: final: super: {
  pythonPackagesOverlays =
    (super.pythonPackagesOverlays or [])
    ++ [
      (_: pprev: {
        qtile = (pprev.qtile.overrideAttrs (_: rec {
        })).overridePythonAttrs (old: let
          flakever = self.shortRev or "dev";
        in {
          version = "0.0.0+${flakever}.flake";
          # use the source of the git repo
          src = ./..;
          # for qtile migrate, not in nixpkgs yet
          propagatedBuildInputs = old.propagatedBuildInputs ++ [ pprev.libcst ];
        });
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
