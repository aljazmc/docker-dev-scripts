#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_GID=$(id -g)
PROJECT_UID=$(id -u)
PHP_VERSION=8.3

## Functions

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

compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    composer:
        image: composer:latest
        command: [[ composer, install ]
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

    myadmin:
        image: phpmyadmin/phpmyadmin
        environment:
            PMA_HOST:               database
            PMA_PORT:               3306
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        ports:
            - 8080:80

    node:
        image: node:current-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        environment:
            HOME:       "$PWD"
            NODE_ENV:   development
            PATH:       "$PWD/.yarn/bin:$PWD/node_modules/.bin:\$PATH"
        network_mode: host

    php:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD

    phpdoc:
        image: phpdoc/phpdoc
        volumes:
            - .:/data

    phpunit:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit

    phpunit-watcher:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit-watcher

    wordpress:
        image: wordpress:latest
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

}

composehack() {

    if  ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/image\:\ [c,n,p,w]/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

configphpunitwatcher() {

if [[ ! -f phpunit-watcher.yml ]]; then
    cat << EOF > phpunit-watcher.yml
watch:
    directories:
        - src
        - tests
    fileMask: '*.php'
    notifications:
        passingTests: false
    phpunit:
        binaryPath: vendor/bin/phpunit
        arguments: '--stop-on-failure'
        timeout: 180
EOF
fi

}

gitignore() {

if [[ ! -f .gitignore ]]; then
    cat << EOF > .gitignore
## Docker related

/docker-compose.yml

## Node/JavaScript related

/.cache
/.config
/.eslintrc.mjs
/.npm
/.pnp.cjs
/.yarn
/.yarnrc
/.yarnrc.yml
/jest.config.js
/node_modules
/package.json
/tsconfig.json
/yarn.lock

## PHP related

/.phpdoc
/.phpunit.cache
/composer.json
/composer.lock
/phpcs.xml
/phpunit-watcher.yml
/phpunit.xml
/vendor

## WordPress related

.htaccess
index.php
license.txt
readme.html
wp-activate.php
wp-admin/
wp-blog-header.php
wp-comments-post.php
wp-config-docker.php
wp-config-sample.php
wp-config.php
wp-content/
wp-cron.php
wp-includes/
wp-links-opml.php
wp-load.php
wp-login.php
wp-mail.php
wp-settings.php
wp-signup.php
wp-trackback.php
xmlrpc.php
EOF
fi

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    configphpunitwatcher
    gitignore
    
    if [[ ! -d src ]]; then

        ## Creating directory structure
        mkdir -p {src/{assets/{ts,scss,fonts,img},parts,patterns,styles,templates},tests/{ts,php}}
      
        ## Setting up node related stuff
        docker compose run --rm node yarn init
      
        ## Setting up php related stuff
        docker compose run --rm composer init
      
        docker compose run --rm composer config allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
        docker compose run --rm composer composer require --dev dealerdirect/phpcodesniffer-composer-installer
        docker compose run --rm composer require --dev composer "squizlabs/php_codesniffer:^3.13"
        docker compose run --rm composer require --dev composer wp-coding-standards/wpcs
        docker compose run --rm composer require --dev composer sirbrillig/phpcs-variable-analysis
        docker compose run --rm composer require --dev phpcompatibility/phpcompatibility-wp
        docker compose run --rm composer require --dev composer phpunit/phpunit
        docker compose run --rm composer require --dev composer spatie/phpunit-watcher
        docker compose run --rm phpunit --generate-configuration
        cp vendor/wp-coding-standards/wpcs/phpcs.xml.dist.sample phpcs.xml

    else

        docker compose run --rm composer install
        docker compose run --rm node yarn install

    fi

    docker compose up -d && \
    sleep 30 && \
    docker compose run --rm wpcli
    ## `ls /usr/bin | grep terminal` -- sh -c "docker compose run --rm phpunit-watcher watch"

}

"$1"
