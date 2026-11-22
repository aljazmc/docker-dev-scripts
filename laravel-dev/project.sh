#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
PHP_VERSION=8.4

## Functions

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
        working_dir: /app
        command: [ composer, install ]
        volumes:
            - .:/app
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

    laravel:
        build:
            context: .
            args:
                PHP_VERSION: $PHP_VERSION
        working_dir: /var/www/html
        volumes:
            - .:/var/www/html
        ports:
            - 80:80
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

    node:
        image: aljazmc/corepack-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        environment:
            HOME:       "$PWD"
            NODE_ENV:   development
            PATH:       "$PWD/node_modules/.bin:\$PATH"
        network_mode: host
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

dotenv() {

    if [[ ! -f .env ]]; then
        cp .env.example .env
        sed -i '/^#\? *DB_/d' .env
        cat << EOF >> .env

DB_CONNECTION=mariadb
DB_HOST=database
DB_PORT=3306
DB_DATABASE=$PROJECT_NAME
DB_USERNAME=$PROJECT_NAME
DB_PASSWORD=$PROJECT_NAME
EOF
        docker compose run --rm laravel php artisan key:generate
    fi

}

gitignore() {

    touch .gitignore

    for entry in /docker-compose.yml /.cache /.config /.npm; do
        if ! grep -qxF "$entry" .gitignore; then
            echo "$entry" >> .gitignore
        fi
    done

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    if [[ ! -f artisan ]]; then

        ## composer create-project needs an empty directory
        rm -rf laravel
        docker compose run --rm composer create-project \
            --no-install --no-scripts --no-interaction laravel/laravel laravel
        rm -f laravel/README.md
        cp -a laravel/. .
        rm -rf laravel

        ## resolve dependencies for the PHP version of the laravel service
        docker compose run --rm composer config platform.php "$PHP_VERSION.0"

    fi

    gitignore

    docker compose run --rm composer install
    dotenv
    docker compose run --rm laravel php artisan migrate --force

    docker compose run --rm node npm install
    docker compose run --rm node npm run build

    docker compose up -d && \
    echo "Site: http://localhost  phpMyAdmin: http://localhost:8080"

}

"$1"
