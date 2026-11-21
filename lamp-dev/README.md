# lamp-dev

Dockerized LAMP (Linux, Apache, MariaDB, PHP) development environment.

## > Usage

```
./project.sh start      # build the image, generate the project, run the tests and start the services
./project.sh autoload   # regenerate the optimized Composer autoloader
./project.sh clean
```

`./project.sh start` generates a small PHP project: `public/index.php` (the document root) connects to the database with PDO and greets with `src/Hello.php`, which is tested in `tests/HelloTest.php`. Classes in `src` are autoloaded under the `App\` namespace. The development dependencies are PHPUnit, PHPUnit Watcher and PHP_CodeSniffer (PSR-12). Existing files are not overwritten, so you can develop your own project in their place.

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `lamp-dev`.

| Service    | URL                   | Credentials       |
| ---------- | --------------------- | ----------------- |
| Apache     | http://localhost      |                   |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>` |

The `web` service passes the database settings to PHP as the `DB_HOST`, `DB_NAME`, `DB_USER` and `DB_PASSWORD` environment variables. Run the tools with:

```
docker compose run --rm phpunit
docker compose run --rm phpunit-watcher watch
docker compose run --rm composer exec phpcs
```

## > License

PHP is licensed under the [PHP License](https://www.php.net/license/), Apache HTTP Server under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) and MariaDB Server under the [GNU General Public License, version 2](https://mariadb.com/kb/en/mariadb-license/).
