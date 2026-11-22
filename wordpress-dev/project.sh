#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
PHP_VERSION=8.4

## Functions

autoload() {

    docker compose run --rm composer dump-autoload -o

}

clean() {

    docker compose --profile tools down -v --rmi all --remove-orphans

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
            /README.md/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    composer:
        image: composer:latest
        command: [ composer, install ]
        volumes:
            - .:/app
        environment:
            - COMPOSER_CACHE_DIR=/var/cache/composer
        profiles: [ tools ]

    database:
        image: mariadb:latest
        volumes:
            - db_data:/var/lib/mysql
        environment:
            MARIADB_ROOT_PASSWORD:  $PROJECT_NAME
            MARIADB_DATABASE:       $PROJECT_NAME
            MARIADB_USER:           $PROJECT_NAME
            MARIADB_PASSWORD:       $PROJECT_NAME
        healthcheck:
            test: [ CMD, healthcheck.sh, --connect, --innodb_initialized ]
            interval: 5s
            timeout: 5s
            retries: 30

    myadmin:
        image: phpmyadmin/phpmyadmin
        environment:
            PMA_HOST:               database
            PMA_PORT:               3306
            MYSQL_ROOT_PASSWORD:    $PROJECT_NAME
        ports:
            - 8080:80
        depends_on:
            - database

    node:
        image: aljazmc/corepack-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        environment:
            HOME:       "$PWD"
            NODE_ENV:   development
            PATH:       "$PWD/.yarn/bin:$PWD/node_modules/.bin:\$PATH"
        network_mode: host
        profiles: [ tools ]

    php:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        profiles: [ tools ]

    phpdoc:
        image: phpdoc/phpdoc
        volumes:
            - .:/data
        profiles: [ tools ]

    phpunit:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit
        profiles: [ tools ]

    phpunit-watcher:
        image: php:$PHP_VERSION-fpm-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit-watcher
        profiles: [ tools ]

    wordpress:
        image: wordpress:php$PHP_VERSION-apache
        volumes:
            - .:/var/www/html/
        ports:
            - 80:80
        healthcheck:
            ## the entrypoint writes wp-config.php after copying WordPress
            test: [ CMD, test, -f, /var/www/html/wp-config.php ]
            interval: 2s
            timeout: 5s
            retries: 60
        depends_on:
            database:
                condition: service_healthy
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME

    wpcli:
        image: wordpress:cli-php$PHP_VERSION
        command: /bin/sh -c ' \
            wp core install \
            --path="/var/www/html" \
            --url="http://localhost" \
            --title="$PROJECT_NAME" \
            --admin_user="$PROJECT_NAME" \
            --admin_password="$PROJECT_NAME" \
            --admin_email=foo@bar.com \
            --skip-email; '
        volumes_from:
            - wordpress
        depends_on:
            wordpress:
                condition: service_healthy
        environment:
            WORDPRESS_DB_HOST:      database
            WORDPRESS_DB_USER:      $PROJECT_NAME
            WORDPRESS_DB_PASSWORD:  $PROJECT_NAME
            WORDPRESS_DB_NAME:      $PROJECT_NAME
        profiles: [ tools ]

volumes:
    db_data:
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/image\:\ [c,n,p,w]/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

composerjson() {

    if [[ ! -f composer.json ]]; then
        cat << EOF > composer.json
{
    "name": "$PROJECT_NAME/$PROJECT_NAME",
    "type": "project",
    "config": {
        "allow-plugins": {
            "dealerdirect/phpcodesniffer-composer-installer": true
        },
        "platform": {
            "php": "$PHP_VERSION.0"
        }
    }
}
EOF
    fi

}

configphpunit() {

    if [[ ! -f phpunit.xml ]]; then
        cat << 'EOF' > phpunit.xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         cacheDirectory=".phpunit.cache"
         colors="true">
    <testsuites>
        <testsuite name="default">
            <directory>tests/php</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
EOF
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

yarninit() {

    ## yarn init also creates these files, remove the ones that did not exist before
    local extras=(.editorconfig .gitattributes .git README.md) created=() file

    for file in "${extras[@]}"; do
        [[ -e $file ]] || created+=("$file")
    done

    docker compose run --rm node yarn init

    for file in "${created[@]}"; do
        rm -rf "./$file"
    done

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
        yarninit

        ## Setting up php related stuff
        composerjson
        configphpunit

        docker compose run --rm composer require --dev \
            dealerdirect/phpcodesniffer-composer-installer \
            "squizlabs/php_codesniffer:^3.13" \
            wp-coding-standards/wpcs \
            sirbrillig/phpcs-variable-analysis \
            phpcompatibility/phpcompatibility-wp \
            phpunit/phpunit \
            spatie/phpunit-watcher
        cp vendor/wp-coding-standards/wpcs/phpcs.xml.dist.sample phpcs.xml

    else

        docker compose run --rm composer install
        docker compose run --rm node yarn install

    fi

    ## waits until the database is ready and WordPress is copied
    docker compose up -d && \
    docker compose run --rm wpcli && \
    echo "Site: http://localhost  phpMyAdmin: http://localhost:8080"
    ## `ls /usr/bin | grep terminal` -- sh -c "docker compose run --rm phpunit-watcher watch"

}

"$1"
