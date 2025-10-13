{ lib, psyclyxLib, ... }:
let
  inherit (lib)
    runTests
    evalModules
    pipe
    flip
    ;
  inherit (psyclyxLib.network) genInterfaces modules;
  inherit (psyclyxLib.test) genTests;

  mkEvalWithModules = modules: cfgs: evalModules { modules = modules ++ cfgs; };

  tests = {
    genInterfaces = {
      f = genInterfaces;

      cases = {
        trivial = {
          case = {
            base = {
              portType = "patch";
            };
            prefix = "patch";
            start = 1;
            count = 1;
          };

          expected = {
            patch1.portType = "patch";
          };
        };

        bulk = {
          case = {
            base.portType = "sfp+";
            prefix = "eno";
            start = 2;
            count = 3;
          };

          expected = {
            eno2.portType = "sfp+";
            eno3.portType = "sfp+";
            eno4.portType = "sfp+";
          };
        };
      };

    };

    interfacesModule =
      let
        evalWithModules = mkEvalWithModules [ modules.interfaces ];
      in
      {
        f = mkEvalWithModules [ modules.interfaces ];
        cases = {
          trivial = [ { eth0.portType = "patch"; } ];
          expected = {
            eth0.portType = "patch";
          };
        };
      };
  };
in
genTests tests
