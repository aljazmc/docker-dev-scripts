# django-dev

Dockerized development environment for the [Django](https://www.djangoproject.com) web framework with PostgreSQL.

## > Usage

```
./project.sh start      # build the image, generate the project, migrate and start the services
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `django-dev`.

| Service | URL                         | Credentials                     |
| ------- | --------------------------- | ------------------------------- |
| Django  | http://localhost:8000       |                                 |
| Admin   | http://localhost:8000/admin | `<name>` / `<name>`             |
| Adminer | http://localhost:8080       | PostgreSQL, `<name>` / `<name>` |

`./project.sh start`:

1. creates `requirements.txt` with `Django` and `psycopg[binary]` if it is missing, and installs it into the virtual environment `.venv/`
2. on the first run generates a project with the `config` settings package and appends the database settings to `config/settings.py`, which read the environment set in `docker-compose.yml`
3. applies the migrations, creates the superuser if it does not exist and runs the tests
4. starts `runserver` and Adminer

Existing files are not overwritten, so you can develop your own project in their place. Add packages to `requirements.txt` and run `./project.sh start` again to install them. The services wait for the database's health check, so no fixed delays are needed.

Run other commands in the `django` container, e.g.:

```
docker compose run --rm django python manage.py startapp blog
docker compose run --rm django python manage.py test
```

## > Image

Based on `debian:13.7` with `python3` and `python3-venv`. `.venv/bin` is first in `PATH`, so `python` and `pip` are the virtual environment's.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > License

Django is free and open-source software licensed under the [BSD 3-Clause License](https://github.com/django/django/blob/main/LICENSE).
