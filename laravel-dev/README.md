# laravel-dev

Dockerized development environment for the [Laravel](https://laravel.com) web framework with MariaDB.

## > Usage

```
./project.sh start      # build the image, generate the project, migrate, build the assets and start the services
./project.sh clean
```

`./project.sh start` generates a project from `laravel/laravel`, configures `.env` for the `database` service, generates the application key, runs the migrations and builds the frontend assets with Vite. Existing files are not overwritten, so you can develop your own application in their place.

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `laravel-dev`.

| Service    | URL                   | Credentials       |
| ---------- | --------------------- | ----------------- |
| Laravel    | http://localhost      |                   |
| phpMyAdmin | http://localhost:8080 | `root` / `<name>` |

Run Artisan, Composer and npm in their containers, e.g.:

```
docker compose run --rm laravel php artisan make:controller HelloController
docker compose run --rm laravel php artisan test
docker compose run --rm composer require laravel/sanctum
docker compose run --rm node npm run dev
```

## > License

Laravel is free and open-source software licensed under the [MIT License](https://github.com/laravel/framework/blob/master/LICENSE.md).
