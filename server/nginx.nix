{ callPackage
, lib
, nginxModules
, enableFastCgiCache
, enablePageSpeed
, ...
}:
callPackage <nixpkgs/pkgs/servers/http/nginx/mainline.nix> {
  modules = [
      nginxModules.dav
      nginxModules.moreheaders
    ]
    ++ lib.optional enableFastCgiCache nginxModules.fastcgi-cache-purge
    ++ lib.optional enablePageSpeed    nginxModules.pagespeed
  ;
}
