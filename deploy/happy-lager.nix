{ callPackage
, fetchFromGitHub
}:
callPackage ./craft-app-template.nix {} {
  appName   = "craft-cms-demo-happy-lager";
  appSource = fetchFromGitHub {
    owner  = "pixelandtonic";
    repo   = "HappyLager";
    rev    = "35f1ac5720d74f9f5c2bd2ce2180fae94cb97d92";
    sha256 = "1ma51j0i9pc6h4c65ndz8b9256m1fqqsa8hhq4ss39ybdk8qlxvb";
  };
  writeable = {
    paths   = ["craft/config" "public/assets"];
    sysPath = "/var/lib/phpfpm/happy-lager-craft-cms-demo";
    owner   = "nginx";
  };
}
