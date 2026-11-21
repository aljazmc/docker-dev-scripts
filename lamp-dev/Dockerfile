ARG PHP_VERSION=8.4

FROM php:$PHP_VERSION-apache-trixie

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN <<'END'
docker-php-ext-install mysqli pdo_mysql
a2enmod rewrite
sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
END
