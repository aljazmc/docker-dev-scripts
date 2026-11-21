# django-dev

Dockerized development environment for the [Django](https://www.djangoproject.com) web framework with PostgreSQL.

## > Usage

```
./project.sh start      # build the image, generate the project, migrate and start the services
./project.sh clean
```

`./project.sh start` creates a virtual environment in `.venv`, installs the packages from `requirements.txt` (`Django` and `psycopg[binary]`), generates a project with the `config` settings package, applies the migrations, creates a superuser and runs the tests. Existing files are not overwritten, so you can develop your own project in their place. Add packages to `requirements.txt` and run `./project.sh start` again to install them.

`<name>` below stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `django-dev`.

| Service    | URL                         | Credentials                     |
| ---------- | --------------------------- | ------------------------------- |
| Django     | http://localhost:8000       |                                 |
| Admin      | http://localhost:8000/admin | `<name>` / `<name>`             |
| Adminer    | http://localhost:8080       | PostgreSQL, `<name>` / `<name>` |

The database settings are appended to `config/settings.py` and read from the environment set in `docker-compose.yml`. Run other commands in the container, e.g.:

```
docker compose run --rm django python manage.py startapp blog
docker compose run --rm django python manage.py test
```

## > License

Django is free and open-source software licensed under the [BSD 3-Clause License](https://github.com/django/django/blob/main/LICENSE).
