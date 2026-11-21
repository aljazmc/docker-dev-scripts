# wordpress-dev

Dockerized development environment for [WordPress](https://wordpress.org) themes and plugins, with MariaDB, PHP 8.4, Node.js and the WordPress coding standards.

## > Usage

```
./project.sh start      # generate the project, install the dependencies, start and install WordPress
./project.sh autoload   # regenerate the optimized Composer autoloader
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `wordpress-dev`.

| Service        | URL                       | Credentials         |
| -------------- | ------------------------- | ------------------- |
| WordPress      | http://localhost          | `<name>` / `<name>` |
| Administration | http://localhost/wp-admin | `<name>` / `<name>` |
| phpMyAdmin     | http://localhost:8080     | `root` / `<name>`   |

On the first run (no `src/` yet) `./project.sh start`:

1. creates the theme structure `src/{assets/{ts,scss,fonts,img},parts,patterns,styles,templates}` and `tests/{ts,php}`
2. runs `yarn init` (and removes the `README.md`, `.git`, `.editorconfig` and `.gitattributes` it would add, if they did not exist before)
3. writes `composer.json` and `phpunit.xml`, and installs PHP_CodeSniffer with the [WordPress coding standards](https://github.com/WordPress/WordPress-Coding-Standards), PHPCompatibilityWP, VariableAnalysis, PHPUnit and PHPUnit Watcher. `phpcs.xml` is copied from the WPCS sample.

On later runs it runs `composer install` and `yarn install` instead. It then starts WordPress, which copies its files into this directory, and installs it with WP-CLI. The services wait for the database's health check, so no fixed delays are needed.

The tool containers (`composer`, `node`, `php`, `phpdoc`, `phpunit`, `phpunit-watcher` and `wpcli`) are in the `tools` profile: `docker compose up -d` does not start them, `docker compose run --rm <service>` does. For example:

```
docker compose run --rm phpunit
docker compose run --rm phpunit-watcher watch
docker compose run --rm composer exec phpcs
docker compose run --rm node yarn add -D sass
docker compose run --rm wpcli wp plugin list
```

`PHP_VERSION` in `project.sh` sets the PHP version of all PHP images (`wordpress:php8.4-apache`, `wordpress:cli-php8.4`, `php:8.4-fpm-alpine`) and of Composer's dependency resolution.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > License

WordPress is free and open-source software licensed under the [GNU General Public License, version 2 or later](https://wordpress.org/about/license/). The WordPress coding standards are licensed under the [MIT License](https://github.com/WordPress/WordPress-Coding-Standards/blob/develop/LICENSE).
