# haskell-dev

Dockerized development environment for [Haskell](https://www.haskell.org) with [Stack](https://docs.haskellstack.org).

## > Usage

```
./project.sh start      # build the image, generate `helloworld.hs` if it is missing, compile and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `helloworld.hs`, a "Hello, World!" program, then compiles it with `stack ghc` and runs it in the `haskell` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with `haskell-stack` and `g++`. On the first run Stack downloads GHC into `.stack/` in this directory.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm haskell bash
```

## > License

GHC is free and open-source software licensed under a [BSD-style license](https://gitlab.haskell.org/ghc/ghc/-/blob/master/LICENSE), Stack under the [BSD 3-Clause License](https://github.com/commercialhaskell/stack/blob/master/LICENSE).
