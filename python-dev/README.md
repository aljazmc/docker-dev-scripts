# python-dev

Dockerized development environment for [Python](https://www.python.org).

## > Usage

```
./project.sh start      # build the image, generate `hello.py` if it is missing, compile and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `hello.py`, a "Hello, world!" program, then compiles it to `hello.pyc` and runs it in the `python` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with `python3`. For a web project with a database see `django-dev`.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm python bash
```

## > License

Python is free and open-source software licensed under the [Python Software Foundation License](https://docs.python.org/3/license.html).
