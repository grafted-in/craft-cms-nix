# https://craftcms.com/docs/requirements
# https://craftcms.com/docs/installing

{ allowHttps
, domain
}:
let
  rootUrl = (if allowHttps then "https" else "http") + "://" + domain;

  traced = x: builtins.trace x x;

  phpFpmListen = "/run/phpfpm/craft-pool.sock";

  defaultDbSetup = pkgs: pkgs.writeText "default-db-setup.sql" ''
    SET NAMES utf8mb4;
  '';

in {
  network = {
    description = "Craft CMS Demo - Happy Lager";
    #enableRollback = true;
  };

  craft-main = args@{ config, pkgs, ... }: let
    # This is not being used but can be useful for testing/development:
    phpTestIndex = pkgs.writeTextDir "index.php" "<?php var_export($_SERVER)?>";

    app = pkgs.callPackage ./happy-lager.nix {};

    nginxConfig = import ./nginx-config.nix {
      inherit config domain phpFpmListen;
      appRoot = "${app.package}/public";
    };
  in {
    networking = {
      hostName = "craft-main";
      firewall.allowedTCPPorts = [80 443];
    };

    environment.systemPackages = with pkgs; [
      gzip unzip nix-repl php vim zip
    ];

    nixpkgs.config = {
      allowUnfree = true;
    };

    services.nginx = {
      enable = true;
      httpConfig = traced (if allowHttps then nginxConfig.secure else nginxConfig.insecure);
    };

    services.mysql = {
      enable = true;

      # Craft claims it does NOT support MariaDB which is the default MySQL package.
      # Also note that for this version of MySQL some extra Craft configuration is needed for
      # Craft 2 (not Craft 3): http://craftcms.stackexchange.com/q/12084/5952
      # BUT we're going to use MariaDB anyway because it's been working fine.
      # package = pkgs.mysql57;

      # TODO: Default character encodings and collation
      extraOptions = ''
        sql_mode="STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"
      '';

      initialDatabases = [
        {
          name   = "happylager";
          schema = "${app.package}/happylager.sql";
        }
      ];
    };

    services.phpfpm = {
      phpOptions = ''
        extension = ${pkgs.phpPackages.imagick}/lib/php/extensions/imagick.so
        zend_extension = "${pkgs.phpPackages.xdebug}/lib/php/extensions/xdebug.so"
      '';

      pools.craft-pool = {
        listen = phpFpmListen;
        extraConfig = ''
          user  = ${config.services.nginx.user}
          group = ${config.services.nginx.group}

          listen.owner = ${config.services.nginx.user}
          listen.group = ${config.services.nginx.group}
          listen.mode = 0660

          pm = dynamic
          pm.max_children = 75
          pm.start_servers = 10
          pm.min_spare_servers = 5
          pm.max_spare_servers = 20
          pm.max_requests = 500
        '';
      };
    };

    systemd.services.init-writeable-paths = {
      description   = "Initialize writeable directories for the app";
      wantedBy      = [ "multi-user.target" "phpfpm" ];
      after         = [ "network.target" ];
      serviceConfig = {
        Type      = "oneshot";
        ExecStart = app.initScript;
      };
    };
  } // (
    if allowHttps then {
      security.acme.certs.${domain} = {
        webroot = "/var/www/challenges";
        email   = "admin@graftedindesign.com";
        postRun = "systemctl reload nginx.service";
      };
    } else {}
  );
}
