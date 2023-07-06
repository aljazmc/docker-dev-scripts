#!/bin/bash

## Check for linux and docker compose or quit

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_GID=$(id -g)
PROJECT_UID=$(id -u)
PHP_VERSION=8.3

## Configuration files

if [ ! -f docker-compose.yml ]; then
    cat << EOF > docker-compose.yml
services:
    composer:
        image: composer:latest
        user: $PROJECT_UID:$PROJECT_GID
        command: [ composer, install ]
        volumes:
            - .:/app
        environment:
            - COMPOSER_CACHE_DIR=/var/cache/composer

    database:
        image: mariadb:latest
        volumes:
            - db_data:/var/lib/mysql
        environment:
            MARIADB_ROOT_PASSWORD:  $PROJECT_NAME
            MARIADB_DATABASE:       $PROJECT_NAME
            MARIADB_USER:           $PROJECT_NAME
            MARIADB_PASSWORD:       $PROJECT_NAME

    node:
        image: node:current-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /home/node
        volumes:
            - .:/home/node
        environment:
            NODE_ENV: development
            PATH: "/home/node/.yarn/bin:/home/node/node_modules/.bin:\$PATH"

    phpcbf:
        image: php:$PHP_VERSION-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
            - .:/app
        entrypoint: vendor/bin/phpcbf

    phpcs:
        image: php:$PHP_VERSION-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
            - .:/app
        entrypoint: vendor/bin/phpcs

    phpdoc:
        image: phpdoc/phpdoc
        user: $PROJECT_UID:$PROJECT_GID
        volumes:
            - .:/data

    phpmyadmin:
        image: phpmyadmin/phpmyadmin
        environment:
            PMA_HOST:               database
            PMA_PORT:               3306
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        ports:
            - 8080:80

    phpunit:
        image: php:$PHP_VERSION-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
            - .:/app
        entrypoint: vendor/bin/phpunit

    phpunit-watcher:
        image: php:$PHP_VERSION-fpm-alpine
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /app
        volumes:
            - .:/app
        entrypoint: vendor/bin/phpunit-watcher

    wordpress:
        image: wordpress:latest
        user: $PROJECT_UID:$PROJECT_GID
        volumes:
            - .:/var/www/html/
        links:
            - database
        ports:
            - 80:80
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME

    wpcli:
        image: wordpress:cli
        user: $PROJECT_UID:$PROJECT_GID
        command: /bin/sh -c ' \
            wp core install \
            --path="/var/www/html" \
            --url="http://localhost" \
            --title="$PROJECT_NAME" \
            --admin_user="$PROJECT_NAME" \
            --admin_password="$PROJECT_NAME" \
            --admin_email=foo@bar.com \
            --skip-email; '
        links:
            - wordpress
        volumes_from:
            - wordpress
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME

volumes:
    db_data:
EOF
fi

autoload() {

    docker compose run --rm composer dump-autoload -o

}

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        .cache \
        .config \
        .gitignore \
        .htaccess \
        .npm \
        .phpdoc \
        .phpunit.cache \
        .yarn \
        .yarnrc \
        .yarnrc.yml \
        composer.json \
        composer.lock \
        docker-compose.yml \
        index.php \
        license.txt \
        node_modules \
        package.json \
        phpcs.xml \
        phpunit-watcher.yml \
        phpunit.xml \
        readme.html \
        src \
        tests \
        vendor \
        wp-activate.php \
        wp-admin \
        wp-blog-header.php \
        wp-comments-post.php \
        wp-config-docker.php \
        wp-config-sample.php \
        wp-config.php \
        wp-content \
        wp-cron.php \
        wp-includes \
        wp-links-opml.php \
        wp-load.php \
        wp-login.php \
        wp-mail.php \
        wp-settings.php \
        wp-signup.php \
        wp-trackback.php \
        xmlrpc.php \
        yarn-error.log \
        yarn.lock

}

