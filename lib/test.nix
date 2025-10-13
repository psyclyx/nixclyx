{ lib, ... }:
let
  inherit (lib) concatMapAttrs nameValuePair mapAttrs';
in
{
  genTests =
    let
      mkCaseTest =
        f:
        { case, expected }:
        {
          inherit expected;
          expr = f case;
        };

      mkGroupTests =
        groupName:
        { f, cases }:
        let
          testName = caseName: "test_${groupName}_${caseName}";
          caseTest = mkCaseTest f;
          testAttrPair = caseName: caseSpec: nameValuePair (testName caseName) (caseTest caseSpec);
        in
        mapAttrs' testAttrPair cases;

    in
    groups: concatMapAttrs mkGroupTests groups;
}
