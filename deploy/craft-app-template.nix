{ bash
, callPackage
, fetchFromGitHub
, lib
, runCommand
, writeScript
, ...
}:
let
  required = arg: help: builtins.abort "${arg} is required: ${help}";

  writeableDefault = {
    appPaths = [];           # list of paths in the app to make writeable
    pkgPath  = "_writeable"; # path to create in read-only package that stores original content of writeable paths
    sysPath = required "writeable.sysPath" "system path to store writeable data (e.g. \"/var/lib/phpfpm/my-app\")";
    owner   = required "writeable.owner"   "user which owns the writeable files";
  };
in
{ appName                      # name of craft application
, appSource                    # source code for the Craft application
, configureForApache  ? false  # Will you be using Apache to serve this application?
, installCraft        ? true   # Should "craft/app" be created for you?
, craftPkg            ? callPackage ./craft-cms.nix {}  # If `installCraft`, this craft package will be used.
, writeable           ? writeableDefault
}:
let
  writeable_ = writeableDefault // writeable;
  writeablePaths = ["craft/storage"] ++ writeable_.paths;

  listOfPaths = lib.concatMapStringsSep " " (x: "'${x}'");

  package = runCommand appName {} ''
    cp -r "${appSource}" "$out"
    chmod -R +w "$out"

    ${lib.optionalString installCraft ''
      # Install craft ourselves:
      cp -r "${craftPkg}/craft/app" "$out/craft"
      chmod -R +w "$out/craft/app"
    ''}

    cp "${craftPkg}/public/htaccess" "$out/public/.htaccess"

    # Remove IIS configuration files.
    find "$out" -name "web.config" -delete

    ${lib.optionalString (!configureForApache) ''
      # Remove all Apache httpd configuration files.
      find "$out" -name ".htaccess" -delete
    ''}

    # Make symlinks to writeable directories.
    writeable_orig_dir="$out/${writeable_.pkgPath}"
    mkdir -p "$writeable_orig_dir"
    for thing in ${listOfPaths writeablePaths}; do
      parent=$(dirname "$writeable_orig_dir/$thing")
      mkdir -p "$parent"
      mv "$out/$thing" "$parent"
      ln -s "${writeable_.sysPath}/$thing" "$out/$thing"
    done
  '';

  # Copy the writeable contents of the app to a writeable dir if not already done
  initScript = writeScript "init-writeable-paths" ''
    #!${bash}/bin/bash

    out="${writeable_.sysPath}"

    if [ ! -d "$out" ]; then

      mkdir -p "$out"
      writeable_orig_dir="${package}/${writeable_.pkgPath}"
      for thing in $( ls "$writeable_orig_dir" ); do
        cp -r "$writeable_orig_dir/$thing" "$out"
      done

      chown -R ${writeable_.owner} "$out"
      chmod -R 0744 "$out"

    fi
  '';

in {
  inherit package initScript;
}
