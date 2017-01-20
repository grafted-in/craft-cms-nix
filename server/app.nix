with import ./common.nix;
let
  writeableDefault = {
    appPaths = [];           # list of paths in the app to make writeable
    pkgPath  = "_writeable"; # path to create in read-only package that stores original content of writeable paths
    sysPath  = required "writeable.sysPath" ''system path to store writeable data (e.g. "/var/lib/phpfpm/my-app")'';
    owner    = required "writeable.owner"   "user which owns the writeable files";
  };
in
{ callPackage
, lib
, runCommand
, writeScript
, writeText

, appConfig
, writeable ? writeableDefault
, ...
}:
let
  writeable_ = writeableDefault // writeable;

  # We only care about writeble paths if the app is frozen.
  #   If the app is frozen, we need to specify which paths are writeable.
  #   Otherwise, the whole app is writeable so it doesn't matter.
  writeablePaths = lib.optionals appConfig.freeze (
    ["craft/storage"]
    ++ writeable_.appPaths
  );

  craftPkg = if isNull appConfig.craft
    then null
    else callPackage appConfig.craft {};

  appPkg = callPackage appConfig.appSource {};

  listOfPaths = lib.concatMapStringsSep " " (x: "'${x}'");

  # Builds the app package at a given path.
  buildPackageAt = out: ''
    mkdir -p $(dirname "${out}")  # Make parent directory.

    cp -r "${appPkg}" "${out}"
    chmod -R +w "${out}"

    ${lib.optionalString (!isNull craftPkg) ''
      # Install craft ourselves:
      cp -r "${craftPkg}/craft/app" "${out}/craft"
      chmod -R +w "${out}/craft"
    ''}

    # Remove IIS configuration files.
    find "${out}" -name "web.config" -delete

    # Remove all Apache httpd configuration files.
    find "${out}" -name ".htaccess" -delete

    ${lib.optionalString (writeablePaths != []) ''
      # Make symlinks to writeable directories.
      writeable_orig_dir="${out}/${writeable_.pkgPath}"
      mkdir -p "$writeable_orig_dir"

      for thing in ${listOfPaths writeablePaths}; do
        original_thing="$writeable_orig_dir/$thing"
        parent=$(dirname "$original_thing")
        mkdir -p "$parent"

        # Move any existing data to the frozen writeable dir or create empty directory there.
        mv "${out}/$thing" "$parent" || mkdir -p "$original_thing"

        ln -s "${writeable_.sysPath}/$thing" "${out}/$thing"
      done
    ''}
  '';

  # Copy the original writeable contents of the package to a writeable dir.
  initWriteablePathsFor = package: ''
    mkdir -p "$out"
    writeable_orig_dir="${package}/${writeable_.pkgPath}"
    for thing in $( ls "$writeable_orig_dir" ); do
      cp -r "$writeable_orig_dir/$thing" "$out"
    done
  '';

  # Takes an existing script and makes a initialization script that only runs if the output path
  # has not been built yet.
  mkInitScript = script: writeScript "init-writeable-paths" ''
    #!/bin/sh

    out="${writeable_.sysPath}"

    if [ ! -d "$out" ]; then

      ${script}

      chown -R "${writeable_.owner}" "$out"
      chmod -R 744 "$out"

    else
      echo Output directory already exists. Not building path: "$out"
    fi
  '';

in if appConfig.freeze
  then rec {
    # For a frozen app, we install it as a package and set up writeable paths on first run.
    initScript = mkInitScript (initWriteablePathsFor package);
    package    = runCommand "craft-app" {} (buildPackageAt "$out");
  }
  else rec {
    # For a fully writeable app, we skip package installation and write the app directly to the
    # writeable path on first run.
    initScript = mkInitScript (buildPackageAt package);
    package    = writeable_.sysPath;
  }
