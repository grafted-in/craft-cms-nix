# To get the sha256 hash of a Craft version URL:
#  * Install `nix-prefetch-zip`: `nix-env -i nix-prefetch-zip`
#  * `nix-prefetch-zip --leave-root <url>`

{ fetchzip, runCommand, ... }:
let
  version = "2.6";
  build   = "2958";
in fetchzip {
  url       = "https://download.buildwithcraft.com/craft/${version}/${version}.${build}/Craft-${version}.${build}.zip";
  stripRoot = false;
  sha256    = "1pn19hgrr6ri208wr4d3r3a76cz12q75nv2i11q0swz5nfi4nxwy";
}
