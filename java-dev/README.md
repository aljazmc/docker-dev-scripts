# java-dev

Dockerized development environment for [Java](https://openjdk.org).

## > Usage

```
./project.sh start      # build the image, generate `HelloWorld.java` if it is missing, compile and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `HelloWorld.java`, a "Hello, World" program, then compiles it with `javac` and runs it in the `java` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with `default-jdk` (OpenJDK).

A shell in the container, with this directory as the home directory:

```
docker compose run --rm java bash
```

## > License

OpenJDK is free and open-source software licensed under the [GNU General Public License, version 2, with the Classpath Exception](https://openjdk.org/legal/gplv2+ce.html).
