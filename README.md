[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![lint](https://github.com/aljazmc/docker-dev-scripts/actions/workflows/lint.yml/badge.svg)](https://github.com/aljazmc/docker-dev-scripts/actions/workflows/lint.yml)

# docker-dev-scripts

One-command Docker development environments: 19 environments for languages, mobile apps, games and the web, and 3 monitoring labs. Each lives in its own directory and is set up with `./project.sh start` and removed with `./project.sh clean`, so nothing but Docker needs to be installed on the host.

## > Features

* **fully automated setup:** `./project.sh start` builds or pulls the images, generates `docker-compose.yml` and a working example project, installs the dependencies and runs it
* **nothing overwritten:** existing project files are kept, so you can develop your own project in place of the example and run `./project.sh start` again
* **files owned by you:** on GNU/Linux the containers run with your user and group id
* **simple cleanup:** `./project.sh clean` removes everything the environment created
* **GPU, display and sound:** the graphical environments use the host's GPU (Intel, AMD, NVIDIA), X server and PipeWire/PulseAudio

## > Prerequisites

* GNU/Linux with bash, which the environments are developed and tested on. `android-dev`, `bevy-dev`, `godot-dev`, `heaps-dev`, `ocaml-dev` and `reactnative-dev` require it; the others only use bash and Docker.
* [Docker](https://docs.docker.com/engine/install/) with the compose plugin, installed and running
* for `android-dev` and `reactnative-dev`: `/dev/kvm` (hardware virtualization) and `mate-terminal`

## > Quick start

```
git clone https://github.com/aljazmc/docker-dev-scripts
cd docker-dev-scripts/node-dev
./project.sh start
./project.sh clean
```

## > Environments

### Languages

| Environment | Stack | `./project.sh start` |
| --- | --- | --- |
| [gcc-dev](gcc-dev/) | C with GCC | compiles and runs `main.c` |
| [go-dev](go-dev/) | Go | builds and runs `main.go` |
| [haskell-dev](haskell-dev/) | Haskell with Stack | compiles and runs `helloworld.hs` |
| [java-dev](java-dev/) | Java (OpenJDK) | compiles and runs `HelloWorld.java` |
| [node-dev](node-dev/) | Node.js with Yarn | creates `package.json` or installs its dependencies |
| [ocaml-dev](ocaml-dev/) | OCaml with opam and Dune | sets up opam, builds and runs a Dune project |
| [python-dev](python-dev/) | Python | compiles and runs `hello.py` |
| [rust-dev](rust-dev/) | Rust | installs the stable toolchain, compiles and runs `hello.rs` |

### Mobile

| Environment | Stack | `./project.sh start` |
| --- | --- | --- |
| [android-dev](android-dev/) | Android, Kotlin and Jetpack Compose | downloads the SDK, builds the app and runs it in the emulator |
| [reactnative-dev](reactnative-dev/) | React Native for Android | downloads the SDK, creates the app and runs it in the emulator |

### Games

| Environment | Stack | `./project.sh start` |
| --- | --- | --- |
| [bevy-dev](bevy-dev/) | Bevy (Rust) | builds and runs a game; bundles for Linux and Windows |
| [godot-dev](godot-dev/) | Godot 4.7 with C# | builds and runs a game; bundles for Linux, Windows and macOS |
| [heaps-dev](heaps-dev/) | Heaps on HashLink (Haxe) | builds and runs a game; bundles for Linux, Windows and macOS |

### Web

| Environment | Stack | `./project.sh start` |
| --- | --- | --- |
| [django-dev](django-dev/) | Django, PostgreSQL, Adminer | generates a project, migrates, starts the server |
| [drupal-dev](drupal-dev/) | Drupal 11, MariaDB, phpMyAdmin | generates a Composer project, installs Drupal with Drush |
| [joomla-dev](joomla-dev/) | Joomla, MariaDB, phpMyAdmin | installs Joomla, adds PHPUnit and PHP_CodeSniffer |
| [lamp-dev](lamp-dev/) | Apache, MariaDB, PHP 8.4, phpMyAdmin | generates a tested PHP project, starts the services |
| [laravel-dev](laravel-dev/) | Laravel, MariaDB, phpMyAdmin, Node.js | generates a project, migrates, builds the assets |
| [wordpress-dev](wordpress-dev/) | WordPress, MariaDB, PHP 8.4, Node.js, phpMyAdmin | sets up theme development, installs WordPress |

### Monitoring labs

| Environment | Stack | `./project.sh start` |
| --- | --- | --- |
| [prometheus-lab](prometheus-lab/) | WordPress, Prometheus, exporters, Grafana | monitors WordPress, Apache and MariaDB |
| [victoriametrics-lab](victoriametrics-lab/) | WordPress, VictoriaMetrics, exporters, Grafana | monitors WordPress, Apache and MariaDB |
| [zabbix-lab](zabbix-lab/) | WordPress, Zabbix, Grafana | monitors WordPress, Apache and MariaDB |

The web environments and labs publish their services on `localhost` (port 80 for the site, 8080 for the database tool, 3000 for Grafana), so run one of them at a time. Each environment's `README.md` lists its URLs, credentials and further commands.

## > Structure

Each environment directory contains:

* `project.sh` - generates `docker-compose.yml` and the project files, then starts the environment. The functions it can run are its arguments: `start` and `clean` everywhere, and e.g. `bundleforlinux`, `autoload` or `traffic` where the README mentions them.
* `Dockerfile` - builds the development image, mostly from `debian:13.7`. `joomla-dev`, `wordpress-dev` and the labs use prebuilt images only.
* `README.md` - what `start` does, the generated files, the services and the license of the main project

Everything else in an environment directory is generated and ignored by git.

> [!CAUTION]
> `./project.sh clean` is meant for developing `project.sh` itself: it removes **all** files in the environment directory except `Dockerfile`, `project.sh` and `README.md`, and runs `docker compose down -v --rmi all --remove-orphans`, which removes the environment's containers, networks, volumes (including databases) and images. Other Docker projects are left untouched. When you develop your own project in an environment, change `clean` first!

## > Tests

```
bash tests/test_compose.sh
shellcheck */project.sh tests/*.sh
```

`tests/test_compose.sh` runs `./project.sh compose` and `composehack` of every environment in a temporary directory, with `docker` replaced by a stand-in, and checks that `docker-compose.yml` is written and gets your user and group id once. The [lint](.github/workflows/lint.yml) workflow runs shellcheck on every push and pull request.

## > License

[MIT](LICENSE). The environments download and run third-party software under its own licenses, which each environment's `README.md` lists.
