# laravel-dev

Dockerized development environment for the [Laravel](https://laravel.com) web framework with MariaDB.

## > Usage

```
./project.sh start      # build the image, generate the project, migrate, build the assets and start the services
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `laravel-dev`.

| Service    | URL                   | Credentials       |
| ---------- | --------------------- | ----------------- |
| Laravel    | http://localhost      |                   |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>` |

On the first run (no `artisan` yet) `./project.sh start` generates a project from `laravel/laravel`. On every run it then installs the Composer dependencies, creates `.env` for the `database` service with an application key if it is missing, runs the migrations, installs the npm packages and builds the frontend assets with Vite. Existing files are not overwritten, so you can develop your own application in their place. The services wait for the database's health check, so no fixed delays are needed.

The tool containers (`composer` and `node`) are in the `tools` profile: `docker compose up -d` does not start them, `docker compose run --rm <service>` does. Artisan runs in the `laravel` container. For example:

```
docker compose run --rm laravel php artisan make:controller HelloController
docker compose run --rm laravel php artisan test
docker compose run --rm composer require laravel/sanctum
docker compose run --rm node npm run dev
```

`node` uses the host's network, so the Vite development server is reachable on `localhost`.

## > Image

`laravel` is built from `php:8.4-apache-trixie` with the `mysqli` and `pdo_mysql` extensions, `mod_rewrite`, the document root in `public/` and PHP's development settings. `PHP_VERSION` in `project.sh` sets the PHP version of the image and of Composer's dependency resolution.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > License

Laravel is free and open-source software licensed under the [MIT License](https://github.com/laravel/framework/blob/master/LICENSE.md).
