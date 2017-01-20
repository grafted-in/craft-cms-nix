rec {
  # Simple name used for directories, etc.
  # WARNING: Changing this after a deployment will change the location of data directories and will
  #          likely result in a partial reset of your application. You must move data from the
  #          previous app folders to the new ones.
  name        = "happy-lager";

  description = "Craft CMS Site";  # Brief, one-line description or title
  host        = "happylager.dev";
  adminEmail  = "admin@happylager.dev";

  # Hosts that get redirected to the primary host.
  hostRedirects = [];

  craft = import ./craft-cms.nix;  # Set to null if your source code already includes craft.
  freeze = true;  # Should the app unwriteable?

  appSource = { fetchFromGitHub, ... }: fetchFromGitHub {
    owner  = "pixelandtonic";
    repo   = "HappyLager";
    rev    = "35f1ac5720d74f9f5c2bd2ce2180fae94cb97d92";
    sha256 = "1ma51j0i9pc6h4c65ndz8b9256m1fqqsa8hhq4ss39ybdk8qlxvb";
  };
  writeablePaths = ["craft/config" "public/assets"];  # Only matters if freeze is true.

  dbConfig = {
    isLocal     = true; # if `true`, MySQL will be installed on the server.
    name        = "happylager";  # database name
    user        = "root";
    password    = "";
    host        = "localhost";
    charset     = "utf8mb4";
    tablePrefix = "craft_";
  };

  # Server settings
  enableHttps        = true;
  enableOpCache      = true;
  enableFastCgiCache = false;  # We don't have a way to clear the cache yet.
  enablePageSpeed    = false;  # We likely won't benefit much from the Google PageSpeed module.
  enableRollback     = true;
}
