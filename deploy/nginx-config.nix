# https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/

{ config        # system configuration

, domain        # domain for this site
, appRoot       # root directory to serve
, phpFpmListen  # listen setting for PHP-FPM
}:
let

  secureConfig = ''
    server {
      server_name ${domain};
      ${listenPart.insecure}

      location /.well-known/acme-challenge {
        root "/var/www/challenges";
      }

      location / {
        return 301 https://${domain}$request_uri;
      }
    }

    server {
      server_name ${domain};
      ${listenPart.secure}

      ${tlsPart}
      ${serverPart}
    }
  '';

  insecureConfig = ''
    server {
      server_name ${domain};
      ${listenPart.insecure}

      ${serverPart}
    }
  '';

  # Listen for both IPv4 & IPv6 requests with http2 enabled
  listenPart = {
    secure = ''
      listen 443 ssl http2;
      listen [::]:443 ssl http2;
    '';

    insecure = ''
      listen 80;
      listen [::]:80;
    '';
  };

  tlsPart = ''
    # SSL/TLS configuration, with TLS1 disabled
    ssl_certificate     ${config.security.acme.directory}/${domain}/fullchain.pem;
    ssl_certificate_key ${config.security.acme.directory}/${domain}/key.pem;
    ssl_protocols TLSv1.2 TLSv1.1;  # TODO: TLSv1.3
    ssl_prefer_server_ciphers on;
    #ssl_dhparam /etc/ssl/certs/dhparam.pem;
    ssl_ciphers "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+aRSA+RC4 EECDH EDH+aRSA RC4 !aNULL !eNULL !LOW !3DES !MD5 !EXP !PSK !SRP !DSS !RC4";
    ssl_session_timeout 30m;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;
  '';

  serverPart = ''
    root "${appRoot}";
    index index.html index.htm index.php;
    charset utf-8;

    # 301 Redirect URLs with trailing /'s as per https://webmasters.googleblog.com/2010/04/to-slash-or-not-to-slash.html
    rewrite ^/(.*)/$ /$1 permanent;

    # Change // -> / for all URLs, so it works for our php location block, too
    merge_slashes off;
    rewrite (.*)//+(.*) $1/$2 permanent;

    # Access and error logging
    #access_log off;
    #error_log  /var/log/nginx/SOMEDOMAIN.com-error.log error;
    # If you want error logging to go to SYSLOG (for services like Papertrailapp.com), uncomment the following:
    #error_log syslog:server=unix:/dev/log,facility=local7,tag=nginx,severity=error;

    # Don't send the nginx version number in error pages and Server header
    server_tokens off;

    # Load configuration files from nginx-partials
    include ${./nginx-partials}/*.conf;

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

    # php-fpm configuration
    location ~ [^/]\.php(/|$) {
      fastcgi_split_path_info ^(.+\.php)(/.+)$;
      fastcgi_pass unix:${phpFpmListen};
      fastcgi_index index.php;

      include ${config.services.nginx.package}/conf/fastcgi.conf;
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

    # Misc settings
    sendfile off;
    client_max_body_size 100m;
  '';
in {
  secure   = secureConfig;
  insecure = insecureConfig;
}
