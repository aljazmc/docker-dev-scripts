# rust-dev

Dockerized development environment for [Rust](https://www.rust-lang.org).

## > Usage

```
./project.sh start      # build the image, generate `hello.rs` if it is missing, compile and run it
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`./project.sh start` generates `docker-compose.yml` and `hello.rs`, a "Hello World!" program, then installs the stable toolchain with `rustup` (into `.rustup/` and `.cargo/` in this directory), compiles the program with `rustc` and runs it in the `rust` container and prints its environment variables. Existing files are not overwritten, so you can develop your own project in their place.

On GNU/Linux `project.sh` adds your user and group id to the containers in `docker-compose.yml`, so the files they create in this directory are owned by you.

## > Image

Based on `debian:13.7` with `rustup` and `build-essential`. For games see `bevy-dev`.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm rust bash
```

## > License

Rust is free and open-source software dual-licensed under the [MIT License](https://github.com/rust-lang/rust/blob/master/LICENSE-MIT) or the [Apache License 2.0](https://github.com/rust-lang/rust/blob/master/LICENSE-APACHE), at your option.
