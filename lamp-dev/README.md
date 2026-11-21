# lamp-dev

Dockerized LAMP (Linux, Apache, MariaDB, PHP) development environment.

## > Usage

```
./project.sh start      # build the image, generate the project, run the tests and start the services
./project.sh autoload   # regenerate the optimized Composer autoloader
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `lamp-dev`.

| Service    | URL                   | Credentials       |
| ---------- | --------------------- | ----------------- |
| Apache     | http://localhost      |                   |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>` |

On the first run (no `composer.json` yet) `./project.sh start` generates a small PHP project:

* `public/index.php` - the document root. It connects to the database with PDO and greets with `src/Hello.php`.
* `src/Hello.php` - autoloaded under the `App\` namespace, tested in `tests/HelloTest.php` (`Tests\` namespace)
* `composer.json` with PHPUnit, PHPUnit Watcher and PHP_CodeSniffer, `phpunit.xml`, `phpcs.xml` (PSR-12) and `phpunit-watcher.yml`

On later runs it runs `composer install` instead. It then runs the tests and starts the services. Existing files are not overwritten, so you can develop your own project in their place. The services wait for the database's health check, so no fixed delays are needed.

The `web` service passes the database settings to PHP as the `DB_HOST`, `DB_NAME`, `DB_USER` and `DB_PASSWORD` environment variables. The tool containers (`composer`, `phpunit` and `phpunit-watcher`) are in the `tools` profile: `docker compose up -d` does not start them, `docker compose run --rm <service>` does. For example:

```
docker compose run --rm phpunit
docker compose run --rm phpunit-watcher watch
docker compose run --rm composer exec phpcs
```

## > Image

`web` is built from `php:8.4-apache-trixie` with the `mysqli` and `pdo_mysql` extensions, `mod_rewrite`, the document root in `public/` and PHP's development settings. `PHP_VERSION` in `project.sh` sets the PHP version of the image, of the test containers and of Composer's dependency resolution.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > License

PHP is licensed under the [PHP License](https://www.php.net/license/), Apache HTTP Server under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) and MariaDB Server under the [GNU General Public License, version 2](https://mariadb.com/kb/en/mariadb-license/).
