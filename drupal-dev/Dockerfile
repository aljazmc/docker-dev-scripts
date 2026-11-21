FROM drupal:11-apache-trixie

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive

RUN <<'END'
## drush uses the mysql client for site:install and the sql:* commands
apt-get update
apt-get install --no-install-recommends mariadb-client -y
apt-get dist-clean

## development settings: show errors and pick up code changes immediately
mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
echo 'opcache.revalidate_freq=0' > "$PHP_INI_DIR/conf.d/zz-development.ini"
END
