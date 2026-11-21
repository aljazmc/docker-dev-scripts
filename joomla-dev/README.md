# joomla-dev

Dockerized development environment for the [Joomla!](https://www.joomla.org) content management system with MariaDB.

## > Usage

```
./project.sh start      # install Joomla and start the services
./project.sh autoload   # regenerate the optimized Composer autoloader
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `joomla-dev`. Joomla requires an administrator password of at least 12 characters, so it is `<name>-password`.

| Service       | URL                            | Credentials                  |
| ------------- | ------------------------------ | ---------------------------- |
| Joomla        | http://localhost               |                              |
| Administrator | http://localhost/administrator | `<name>` / `<name>-password` |
| phpMyAdmin    | http://localhost:8080          | `root` / `<name>`            |

On the first start the official `joomla` image copies Joomla into this directory and installs it; `./project.sh start` waits until the installation is finished. On the first run it also generates `composer.json` with PHPUnit and PHP_CodeSniffer, `phpunit.xml` and `phpcs.xml` (PSR-12) for your code in `src/` and `tests/`. The services wait for the database's health check, so no fixed delays are needed.

The tool containers (`composer` and `phpunit`) are in the `tools` profile: `docker compose up -d` does not start them, `docker compose run --rm <service>` does. For example:

```
docker compose run --rm phpunit
docker compose run --rm composer exec phpcs
docker compose exec joomla php cli/joomla.php list
```

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you. `clean` makes `configuration.php`, which Joomla makes read-only, writable before removing it.

## > License

Joomla! is free and open-source software licensed under the [GNU General Public License, version 2 or later](https://docs.joomla.org/Joomla_Licenses).
