# node-dev

Dockerized development environment for [Node.js](https://nodejs.org) with [Yarn](https://yarnpkg.com) through Corepack.

## > Usage

```
./project.sh start      # build the image, create package.json or install its dependencies
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml`, then runs `yarn init -y` if there is no `package.json`, or `yarn install` if there is one, and prints the container's environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

The container uses the host's network (`network_mode: host`), so development servers started in it are reachable on `localhost`.

## > Image

Based on `debian:13.7` with Node.js (`NODE_VERSION` in `Dockerfile`), downloaded from nodejs.org and verified with the release keys, and Corepack installed with npm. `COREPACK_ENABLE_DOWNLOAD_PROMPT=0` lets Corepack download Yarn without asking.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm node bash
```

## > License

Node.js is free and open-source software licensed under the [MIT License](https://github.com/nodejs/node/blob/main/LICENSE), Yarn under the [BSD 2-Clause License](https://github.com/yarnpkg/berry/blob/master/LICENSE.md).
