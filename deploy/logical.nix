# https://craftcms.com/docs/requirements
# https://craftcms.com/docs/installing

{ allowHttps ? false
, domain ? "happylager.dev"
}:
let
  rootUrl = (if allowHttps then "https" else "http") + "://" + domain;

  traced = x: builtins.trace x x;

  wwwUser = "craft";

  writeableDirStr      = "/var/lib/phpfpm/happy-lager-craft-cms-demo";
  writeableOrigDirName = "_writeable";

  # Copy the writeable contents of the app to a writeable dir if not already done
  startupScript = pkgs: app: ''
    #!${pkgs.bash}/bin/bash

    if [ ! -d "${writeableDirStr}" ]; then

      mkdir -p "${writeableDirStr}"
      writeable_orig_dir="${app}/${writeableOrigDirName}"
      for thing in $( ls "$writeable_orig_dir" ); do
        cp -r "$writeable_orig_dir/$thing" "${writeableDirStr}"
      done

      chown -R ${wwwUser}:${wwwUser} "${writeableDirStr}"
      chmod -R 0744 "${writeableDirStr}"

    fi
  '';

  phpFpmListen = "/run/phpfpm/craft-pool.sock";

in {
  network = {
    description = "Craft CMS Demo - Happy Lager";
    #enableRollback = true;
  };

  craft-main = args@{ config, pkgs, ... }: let
    # This is not being used but can be useful for testing/development:
    phpTestIndex = pkgs.writeTextDir "index.php" "<?php var_export($_SERVER)?>";

    app = pkgs.callPackage ./happy-lager.nix {
      inherit writeableDirStr writeableOrigDirName;
    };
  in {
    networking = {
      hostName = "craft-main";
      firewall.allowedTCPPorts = [80 443];
    };

    environment.systemPackages = with pkgs; [
      gzip unzip nix-repl php vim zip
    ];

    users = {
      extraGroups.${wwwUser} = {};
      extraUsers.${wwwUser} = {
        extraGroups = [wwwUser];
      };
    };

    nixpkgs.config = {
      allowUnfree = true;
    };

    services.nginx = let nginxPkg = pkgs.nginx; in {
      enable     = true;
      user       = wwwUser;
      group      = wwwUser;
      package    = nginxPkg;

      # https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/
      httpConfig = ''
        server {
          server_name ${domain};
          listen 80;
          index index.html index.htm index.php;

          root "${app}/public";

          # Root directory location handler
          location / {
            try_files $uri $uri/ /index.php?$query_string;
          }

          # Localized sites, hat tip to Johannes -- https://gist.github.com/johanneslamers/f6d2bc0d7435dca130fc

          # If you are creating a localized site as per: https://craftcms.com/docs/localization-guide
          # the directives here will help you handle the locale redirection so that requests will
          # be routed through the appropriate index.php wherein you set the `CRAFT_LOCALE`

          # Enable this by un-commenting it, and changing the language codes as appropriate
          # Add a new location @XXrewrites and location /XX/ block for each language that
          # you need to support

          #location @enrewrites {
          #  rewrite ^/en/(.*)$ /en/index.php?p=$1? last;
          #}
          #
          #location /en/ {
          #  try_files $uri $uri/ @enrewrites;
          #}

          # Craft-specific location handlers to ensure AdminCP requests route through index.php
          # If you change your `cpTrigger`, change it here as well
          location ^~ /admin {
            try_files $uri $uri/ /index.php?$query_string;
          }
          location ^~ /cpresources {
            try_files $uri $uri/ /index.php?$query_string;
          }

          # PHP-FPM configuration
          location ~ [^/]\.php(/|$) {
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:${phpFpmListen};
            fastcgi_index index.php;

            include ${nginxPkg}/conf/fastcgi.conf;
            fastcgi_param PATH_INFO       $fastcgi_path_info;
            fastcgi_param PATH_TRANSLATED $document_root$fastcgi_path_info;

            # Mitigate https://httpoxy.org/ vulnerabilities
            fastcgi_param HTTP_PROXY "";

            fastcgi_intercept_errors off;
            fastcgi_buffer_size 16k;
            fastcgi_buffers 4 16k;
            fastcgi_connect_timeout 300;
            fastcgi_send_timeout 300;
            fastcgi_read_timeout 300;
          }
        }
      '';
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
          schema = "${app}/happylager.sql";
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
          user  = ${wwwUser}
          group = ${wwwUser}

          listen.owner = ${wwwUser}
          listen.group = ${wwwUser}
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

    systemd.services.init-writeable-dirs = {
      description   = "Initialize writeable directories for the app";
      wantedBy      = [ "multi-user.target" "phpfpm" ];
      after         = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeScript "init-writeable-dirs" (startupScript pkgs app);
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
