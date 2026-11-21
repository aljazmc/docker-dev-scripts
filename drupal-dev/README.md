# drupal-dev

Dockerized development environment for the [Drupal](https://www.drupal.org) content management system with MariaDB.

## > Usage

```
./project.sh start      # build the image, generate the project, install Drupal and start the services
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `drupal-dev`.

| Service    | URL                   | Credentials         |
| ---------- | --------------------- | ------------------- |
| Drupal     | http://localhost      | `<name>` / `<name>` |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>`   |

On the first run (no `composer.json` yet) `./project.sh start` generates a Composer-managed project from `drupal/recommended-project` with [Drush](https://www.drush.org) and [Coder](https://www.drupal.org/project/coder) (PHP_CodeSniffer rules for Drupal), and `phpcs.xml` for `web/modules/custom` and `web/themes/custom`. On later runs it runs `composer install` instead. If the database is empty, Drush installs the standard profile. Existing files are not overwritten, so you can develop your own project in their place. The services wait for the database's health check, so no fixed delays are needed.

Composer, Drush and PHP_CodeSniffer run in the `drupal` container. For example:

```
docker compose run --rm drupal composer require drupal/admin_toolbar
docker compose run --rm drupal drush cache:rebuild
docker compose run --rm drupal phpcs
```

## > Image

`drupal` is built from `drupal:11-apache-trixie` with the MariaDB client for Drush, PHP's development settings and OPcache checking for changed files on every request. The project directory is mounted at `/opt/drupal`, so its `web/` is the document root.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you. `clean` makes `web/sites/default`, which Drupal makes read-only, writable before removing it.

## > License

Drupal is free and open-source software licensed under the [GNU General Public License, version 2 or later](https://www.drupal.org/about/licensing).
