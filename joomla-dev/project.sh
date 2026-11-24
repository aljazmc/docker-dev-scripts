#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
PHP_VERSION=8.4
ADMIN_PASSWORD="$PROJECT_NAME-password" ## Joomla requires at least 12 characters

## Functions

autoload() {

    docker compose run --rm composer dump-autoload -o

}

clean() {

    docker compose --profile tools down -v --rmi all --remove-orphans

    ## Joomla makes configuration.php read-only
    [[ -f configuration.php ]] && chmod u+w configuration.php

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
        image: composer:2.2.32
        working_dir: /app
        command: [ composer, install ]
        volumes:
            - .:/app
        profiles: [ tools ]

    database:
        image: mariadb:11.8.9-ubi
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

    joomla:
        image: joomla:6.2.0
        working_dir: /var/www/html
        volumes:
            - .:/var/www/html
        ports:
            - 80:80
        environment:
            JOOMLA_DB_HOST:         database
            JOOMLA_DB_USER:         $PROJECT_NAME
            JOOMLA_DB_PASSWORD:     $PROJECT_NAME
            JOOMLA_DB_NAME:         $PROJECT_NAME
            JOOMLA_SITE_NAME:       $PROJECT_NAME
            JOOMLA_ADMIN_USER:      $PROJECT_NAME
            JOOMLA_ADMIN_USERNAME:  $PROJECT_NAME
            JOOMLA_ADMIN_PASSWORD:  $ADMIN_PASSWORD
            JOOMLA_ADMIN_EMAIL:     foo@bar.com
        depends_on:
            database:
                condition: service_healthy

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

    phpunit:
        image: php:$PHP_VERSION-cli-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit
        profiles: [ tools ]

volumes:
    db_data:
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

gitignore() {

    if [[ ! -f .gitignore ]]; then
        cat << EOF > .gitignore
## Docker related

/docker-compose.yml

## PHP related

/.phpunit.cache
/composer.lock
/vendor

## Joomla related

/.htaccess
/.joomla-initializing
/LICENSE.txt
/README.txt
/administrator
/api
/cache
/cli
/components
/configuration.php
/files
/htaccess.txt
/images
/includes
/index.php
/installation
/language
/layouts
/libraries
/media
/modules
/plugins
/robots.txt.dist
/templates
/tmp
/web.config.txt
EOF
    fi

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    gitignore

    if [[ ! -f composer.json ]]; then

        mkdir -p src tests

        cat << EOF > composer.json
{
    "name": "$PROJECT_NAME/$PROJECT_NAME",
    "type": "project",
    "config": {
        "platform": {
            "php": "$PHP_VERSION.0"
        }
    }
}
EOF

        cat << 'EOF' > phpcs.xml
<?xml version="1.0"?>
<ruleset name="project">
    <file>src</file>
    <file>tests</file>
    <rule ref="PSR12"/>
</ruleset>
EOF

        cat << 'EOF' > phpunit.xml
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         cacheDirectory=".phpunit.cache"
         colors="true">
    <testsuites>
        <testsuite name="default">
            <directory>tests</directory>
        </testsuite>
    </testsuites>
    <source>
        <include>
            <directory>src</directory>
        </include>
    </source>
</phpunit>
EOF

        docker compose run --rm composer require --dev \
            phpunit/phpunit \
            squizlabs/php_codesniffer

    else

        docker compose run --rm composer install

    fi

    docker compose up -d || return

    echo "Waiting for the Joomla installation to finish."
    for _ in {1..90}; do
        [[ -f configuration.php && ! -d installation ]] && break
        sleep 2
    done

    echo "Site: http://localhost  Administrator: http://localhost/administrator ($PROJECT_NAME / $ADMIN_PASSWORD)  phpMyAdmin: http://localhost:8080"

}

"$1"
