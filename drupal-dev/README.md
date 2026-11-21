# drupal-dev

Dockerized development environment for the [Drupal](https://www.drupal.org) content management system with MariaDB.

## > Usage

```
./project.sh start      # build the image, generate the project, install Drupal and start the services
./project.sh clean
```

`./project.sh start` generates a Composer-managed project from `drupal/recommended-project` with [Drush](https://www.drush.org) and [Coder](https://www.drupal.org/project/coder) (PHP_CodeSniffer rules for Drupal), and installs the standard profile with Drush. Existing files are not overwritten, and Drupal is only installed if the database is empty.

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `drupal-dev`.

| Service    | URL                         | Credentials              |
| ---------- | --------------------------- | ------------------------ |
| Drupal     | http://localhost            | `<name>` / `<name>`      |
| phpMyAdmin | http://localhost:8080       | `root` / `<name>`        |

Put your own modules and themes in `web/modules/custom` and `web/themes/custom`. Composer, Drush and PHP_CodeSniffer run in the `drupal` container, e.g.:

```
docker compose run --rm drupal composer require drupal/admin_toolbar
docker compose run --rm drupal drush cache:rebuild
docker compose run --rm drupal phpcs
```

## > License

Drupal is free and open-source software licensed under the [GNU General Public License, version 2 or later](https://www.drupal.org/about/licensing).
