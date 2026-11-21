#!/bin/bash

## Variables

PROJECT_NAME=$(basename "$PWD") ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
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

    phpunit-watcher:
        image: php:$PHP_VERSION-cli-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        entrypoint: vendor/bin/phpunit-watcher
        profiles: [ tools ]

    web:
        build:
            context: .
            args:
                PHP_VERSION: $PHP_VERSION
        working_dir: /var/www/html
        volumes:
            - .:/var/www/html
        ports:
            - 80:80
        environment:
            DB_HOST:                database
            DB_NAME:                $PROJECT_NAME
            DB_USER:                $PROJECT_NAME
            DB_PASSWORD:            $PROJECT_NAME
        depends_on:
            database:
                condition: service_healthy

volumes:
    db_data:
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
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

## PHP related

/.phpunit.cache
/vendor
EOF
    fi

}

hello() {

    mkdir -p public src tests

    cat << 'EOF' > public/index.php
<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Hello;

$pdo = new PDO(
    'mysql:host=' . getenv('DB_HOST') . ';dbname=' . getenv('DB_NAME'),
    (string) getenv('DB_USER'),
    (string) getenv('DB_PASSWORD'),
);
$version = $pdo->query('SELECT VERSION()')->fetchColumn();

echo '<h1>' . htmlspecialchars((new Hello())->greet('LAMP')) . '</h1>';
echo '<p>PHP ' . PHP_VERSION . ', MariaDB ' . htmlspecialchars((string) $version) . '</p>';
EOF

    cat << 'EOF' > src/Hello.php
<?php

declare(strict_types=1);

namespace App;

final class Hello
{
    public function greet(string $name): string
    {
        return "Hello, {$name}!";
    }
}
EOF

    cat << 'EOF' > tests/HelloTest.php
<?php

declare(strict_types=1);

namespace Tests;

use App\Hello;
use PHPUnit\Framework\TestCase;

final class HelloTest extends TestCase
{
    public function testGreet(): void
    {
        $this->assertSame('Hello, LAMP!', (new Hello())->greet('LAMP'));
    }
}
EOF

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    configphpunitwatcher
    gitignore

    if [[ ! -f composer.json ]]; then

        hello

        cat << EOF > composer.json
{
    "name": "$PROJECT_NAME/$PROJECT_NAME",
    "type": "project",
    "require": {
        "php": ">=$PHP_VERSION",
        "ext-pdo": "*"
    },
    "autoload": {
        "psr-4": {
            "App\\\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\\\": "tests/"
        }
    },
    "config": {
        "platform": {
            "php": "$PHP_VERSION.0"
        }
    }
}
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

        cat << 'EOF' > phpcs.xml
<?xml version="1.0"?>
<ruleset name="project">
    <file>public</file>
    <file>src</file>
    <file>tests</file>
    <rule ref="PSR12"/>
</ruleset>
EOF

        docker compose run --rm composer require --dev \
            phpunit/phpunit \
            spatie/phpunit-watcher \
            squizlabs/php_codesniffer

    else

        docker compose run --rm composer install

    fi

    docker compose run --rm phpunit

    docker compose up -d && \
    echo "Site: http://localhost  phpMyAdmin: http://localhost:8080"
    ## `ls /usr/bin | grep terminal` -- sh -c "docker compose run --rm phpunit-watcher watch"

}

"$1"
