# gcc-dev

Dockerized development environment for C with [GCC](https://gcc.gnu.org).

## > Usage

```
./project.sh start      # build the image, generate `main.c` if it is missing, compile and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `main.c`, a "Hello world!" program, then compiles it to `main` and runs it in the `gcc` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with `gcc` and `libc6-dev`.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm gcc bash
```

## > License

GCC is free software licensed under the [GNU General Public License, version 3 or later](https://gcc.gnu.org/onlinedocs/gcc/Copying.html), with the [GCC Runtime Library Exception](https://www.gnu.org/licenses/gcc-exception-3.1.html) for the runtime libraries.
