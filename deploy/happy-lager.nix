{ callPackage
, fetchFromGitHub
, lib
, runCommand
, writeableDirStr      ? "/var/lib/writeable" # e.g. "/var/lib/phpfpm/HappyLager"
, writeableOrigDirName ? "_writeable"         # e.g. "_writeable"
, configureForApache   ? false
, ...
}:
let
  craft-cms = callPackage ./craft-cms.nix {};

  appName = "craft-cms-demo-happy-lager";

  src = fetchFromGitHub {
    owner  = "pixelandtonic";
    repo   = "HappyLager";
    rev    = "35f1ac5720d74f9f5c2bd2ce2180fae94cb97d92";
    sha256 = "1ma51j0i9pc6h4c65ndz8b9256m1fqqsa8hhq4ss39ybdk8qlxvb";
  };

  writeablePaths = [
    "craft/config"
    "craft/storage"
    "public/assets"
  ];

  listOfPaths = lib.concatMapStringsSep " " (x: "'${x}'");

in runCommand appName {} ''
  cp -r "${src}" "$out"
  chmod -R +w "$out"

  cp -r "${craft-cms}/craft/app" "$out/craft"
  chmod -R +w "$out/craft/app"

  cp "${craft-cms}/public/htaccess" "$out/public/.htaccess"

  # Remove IIS configuration files
  find "$out" -name "web.config" -delete

  # If we're not using Apache httpd, remove all its configuration files.
  ${if !configureForApache
      then ''find "$out" -name ".htaccess" -delete''
      else ""}

  # Make symlinks to writeable directories.
  writeable_orig_dir="$out/${writeableOrigDirName}"
  mkdir -p "$writeable_orig_dir"
  for thing in ${listOfPaths writeablePaths}; do
    parent=$(dirname "$writeable_orig_dir/$thing")
    mkdir -p "$parent"
    mv "$out/$thing" "$parent"
    ln -s "${writeableDirStr}/$thing" "$out/$thing"
  done
''
