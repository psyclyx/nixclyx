{ lib, psyclyxLib, ... }:
let
  driveUUIDs = [
    "2bc66a5a-2960-467d-be90-8637fad208b1"
    "d2218d5f-fe4c-4a5e-a291-d767d28ce1cd"
    "ebffd99b-066c-4ade-9d4c-2129b56778a8"
    "6f37ed57-6b58-4848-a070-87a4eabcc316"
    "e70ec6f1-642d-4f99-b98e-5eb8be363ce1"
    "f40c9b7b-31f7-4b7b-b664-99267a840dca"
    "5f0f2127-ff8a-4f9b-939f-5dfac3cfd8b8"
    "7a7344e5-73a5-484a-a559-e24c08d0614a"
  ];
in
{
  imports = [ ./common.nix ];

  config = {
    networking = {
      hostName = "lab-3";
    };
  };
}
