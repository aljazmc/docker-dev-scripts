# go-dev

Dockerized development environment for [Go](https://go.dev).

## > Usage

```
./project.sh start      # build the image, generate `main.go` if it is missing, build and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `main.go`, a "Hello World!" program, then builds it with `go build` and runs it in the `go` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with Debian's `golang` package.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm go bash
```

## > License

Go is free and open-source software licensed under the [BSD 3-Clause License](https://go.dev/LICENSE).
