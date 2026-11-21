# joomla-dev

Dockerized development environment for the [Joomla!](https://www.joomla.org) content management system with MariaDB.

## > Usage

```
./project.sh start      # install Joomla and start the services
./project.sh clean
```

On the first start the official `joomla` image copies Joomla into the project directory and installs it. `./project.sh start` also generates a `composer.json` with PHPUnit and PHP_CodeSniffer (PSR-12) for the code in `src` and `tests`.

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `joomla-dev`. Joomla requires an administrator password of at least 12 characters, so it is `<name>-password`.

| Service       | URL                              | Credentials                  |
| ------------- | -------------------------------- | ---------------------------- |
| Joomla        | http://localhost                 |                              |
| Administrator | http://localhost/administrator   | `<name>` / `<name>-password` |
| phpMyAdmin    | http://localhost:8080            | `root` / `<name>`            |

Run the tools with:

```
docker compose run --rm phpunit
docker compose run --rm composer exec phpcs
docker compose exec joomla php cli/joomla.php list
```

## > License

Joomla! is free and open-source software licensed under the [GNU General Public License, version 2 or later](https://docs.joomla.org/Joomla_Licenses).
