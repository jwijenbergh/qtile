{
  description = "A flake for Qtile";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=c7b821ba2e1e635ba5a76d299af62821cbcb09f3";

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [(import ./nix/overlays.nix self)];
      });
  in {
    overlays = import ./nix/overlays.nix self;
    packages = forAllSystems (system: let
      pkgs = nixpkgsFor.${system};
    in {
      # packages for NixOS users or just for "nix build" local dev work
      # it pretty much are aliases of the upstream nixpkgs derivation
      # but it is overlayed in nix/overlay.nix (see above)
      qtile-unwrapped = pkgs.python3.pkgs.qtile;
      qtile = let
        unwrapped = self.packages.${system}.qtile-unwrapped;
      in
        (pkgs.python3.withPackages (_: [unwrapped])).overrideAttrs (_: {
          # restore some qtile attrs, beautify name
          inherit (unwrapped) pname version meta;
          name = with unwrapped; "${pname}-${version}";
          passthru.unwrapped = unwrapped;
        });
      default = self.packages.${system}.qtile;
    });
    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        common-shell = {
          env = {
            QTILE_DLOPEN_LIBGOBJECT = "${pkgs.glib.out}/lib/libgobject-2.0.so.0";
            QTILE_DLOPEN_LIBPANGOCAIRO = "${pkgs.pango.out}/lib/libpangocairo-1.0.so.0";
            QTILE_DLOPEN_LIBPANGO = "${pkgs.pango.out}/lib/libpango-1.0.so.0";
            QTILE_DLOPEN_LIBXCBUTILCURSORS = "${pkgs.xcb-util-cursor.out}/lib/libxcb-cursor.so.0";
            QTILE_INCLUDE_LIBPIXMAN = "${pkgs.pixman.outPath}/include";
            QTILE_INCLUDE_LIBDRM = "${pkgs.libdrm.dev.outPath}/include/libdrm";
          };
          shellHook = ''
            export PYTHONPATH=$(readlink -f .):$PYTHONPATH
          '';
        };
        common-python-deps = ps:
          with ps; [
            # deps for running, same as NixOS package
            (cairocffi.override {withXcffib = true;})
            dbus-next
            iwlib
            mpd2
            psutil
            pulsectl-asyncio
            pygobject3
            python-dateutil
            pywayland
            pywlroots
            pyxdg
            xcffib
            xkbcommon

            # building ffi
            setuptools

            # migrate
            libcst

            # tests
            coverage
            pytest
          ];
        common-system-deps = with pkgs; [
          # Gdk namespaces
          wrapGAppsHook
          gobject-introspection

          ## system deps
          libinput
          libxkbcommon
          xorg.xcbutilwm

          # x11 deps
          xorg.xorgserver
          xorg.libX11

          # wayland deps
          wayland
          wlroots_0_16
          # test/backend/wayland/test_window.py
          gtk-layer-shell

          # some targets scripts run
          (
            pkgs.writeScriptBin "qtile-run-tests-wayland" ''
              ./scripts/ffibuild -v
              pytest -x --backend=wayland
            ''
          )

          (
            pkgs.writeScriptBin "qtile-run-tests-x11" ''
              ./scripts/ffibuild -v
              pytest -x --backend=x11
            ''
          )
        ];
      in
        builtins.listToAttrs (
          (builtins.map
            (
              pythonVersion: {
                name = "test-${pythonVersion}";
                value = pkgs.mkShell {
                  packages =
                    [
                      (pkgs."${pythonVersion}".withPackages (
                        ps: (common-python-deps ps)
                      ))
                    ]
                    ++ common-system-deps;
                  inherit (common-shell) env shellHook;
                };
              }
            )
            ["python310" "python311" "python312"])
          ++
          [
          (let
            pkgs-pypy = import (pkgs.applyPatches {
              name = "nixpkgs-pr-240301";
              src = pkgs.path;
              patches = [ (pkgs.fetchpatch {
                url  = "https://patch-diff.githubusercontent.com/raw/NixOS/nixpkgs/pull/240301.patch";
                name = "fix_sysconfig_pypy.patch";
                hash = "sha256-McjXZfk8j31RaHp37IN+lXcJZyQL+MXnr3kj74gZo5o=";
              }) ];
            }) { inherit (pkgs) system; };
          in
            {
              name = "test-pypy310";
              value = pkgs.mkShell {
                packages =
                  [
                    (pkgs.pypy310.withPackages (
                      ps: (common-python-deps ps)
                    ))
                  ]
                  ++ common-system-deps;
                inherit (common-shell) env shellHook;
              };
            })
            {
              name = "default";
              value = pkgs.mkShell {
                packages =
                  with pkgs; [
                    (python3.withPackages (
                      ps:
                        (common-python-deps ps)
                    ))
                    pre-commit
                  ]
                  ++ common-system-deps;
                inherit (common-shell) env shellHook;
              };
            }
          ]
        )
    );
  };
}
