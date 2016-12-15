{ fetchzip, runCommand, ... }:
let
  version = "2.6";
  build   = "2954";
in fetchzip {
  url       = "https://download.buildwithcraft.com/craft/${version}/${version}.${build}/Craft-${version}.${build}.zip";
  stripRoot = false;
  sha256    = "0xl6qfavnx5j5b4nrqsbs2r9lv3m20x66m73j8y75risr0251wrl";
}
