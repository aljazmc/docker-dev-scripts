#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans

    ## Drupal makes web/sites/default read-only
    [[ -d web/sites ]] && chmod -R u+w web/sites

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

    drupal:
        build: .
        working_dir: /opt/drupal
        volumes:
            - .:/opt/drupal
        ports:
            - 80:80
        environment:
            COMPOSER_HOME:          /tmp/composer
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

/vendor

## Drupal related

/web/core
/web/libraries
/web/modules/contrib
/web/profiles/contrib
/web/themes/contrib
/web/sites/*/files
/web/sites/*/private
/web/sites/*/services.yml
/web/sites/*/settings.php
/web/sites/*/settings.local.php
/web/sites/simpletest
EOF
    fi

}

phpcs() {

    if [[ ! -f phpcs.xml ]]; then
        cat << EOF > phpcs.xml
<?xml version="1.0"?>
<ruleset name="$PROJECT_NAME">
    <arg name="extensions" value="php,module,inc,install,test,profile,theme,info,yml"/>
    <file>web/modules/custom</file>
    <file>web/themes/custom</file>
    <exclude-pattern>*/node_modules/*</exclude-pattern>
    <rule ref="Drupal"/>
    <rule ref="DrupalPractice"/>
</ruleset>
EOF
    fi

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    gitignore
    phpcs

    if [[ ! -f composer.json ]]; then

        ## composer create-project needs an empty directory
        rm -rf drupal
        docker compose run --rm --no-deps drupal composer create-project \
            --no-install --no-interaction drupal/recommended-project drupal
        cp -a drupal/. .
        rm -rf drupal

        mkdir -p web/{modules,themes}/custom

        docker compose run --rm --no-deps drupal composer require drush/drush
        docker compose run --rm --no-deps drupal composer config \
            allow-plugins.dealerdirect/phpcodesniffer-composer-installer true
        docker compose run --rm --no-deps drupal composer require --dev drupal/coder

    else

        docker compose run --rm --no-deps drupal composer install

    fi

    if ! docker compose run --rm drupal drush status --field=bootstrap | grep -q Successful; then
        docker compose run --rm drupal drush site:install standard \
            --db-url="mysql://$PROJECT_NAME:$PROJECT_NAME@database:3306/$PROJECT_NAME" \
            --site-name="$PROJECT_NAME" \
            --account-name="$PROJECT_NAME" \
            --account-pass="$PROJECT_NAME" \
            --account-mail=foo@bar.com \
            --yes
    fi

    docker compose up -d && \
    echo "Site: http://localhost  phpMyAdmin: http://localhost:8080"

}

"$1"
