[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# docker-dev-scripts
Scripts to quickly setup dockerized development environments

## > Features

* **fully automated setup**
* **simple one-command start:** with `./project.sh start`.
* **simple one-command cleanup:** with `./project.sh clean`.

## > Prerequisites

* Linux system with bash shell
* Docker (with docker compose plugin) installed and running

## > Structure

Each environment lives in its own subdirectory and consists of:

* `Dockerfile` - builds the development image (except `wordpress-dev`, which uses prebuilt images)
* `project.sh` - generates `docker-compose.yml` and project files, then starts or cleans up the environment
* `README.md` - (`bevy-dev`, `godot-dev`, `heaps-dev`) usage notes, including how to bundle self-contained Linux, Windows and macOS packages and run them

On GNU/Linux, `project.sh` adds your user and group id to `docker-compose.yml`, so generated files are owned by you and not by root.

## > Example

Use case for node development environment:

1. clone the project with:
```
git clone https://github.com/aljazmc/docker-dev-scripts
```
2. move to the desired subdirectory:
```
cd node-dev
```
3. download and setup everything necessary with:
```
./project.sh start
```
4. after use you can quickly clean up with: 
```
./project.sh clean
```

> [!CAUTION]
> Function "clean" is used in the development of "project.sh" script to remove **ALL** generated files and folders (everything except `Dockerfile`, `project.sh` and `README.md`). It also runs `docker system prune -af --volumes`, which removes **ALL** unused Docker images, containers, networks and volumes on your system, not only the ones belonging to this project. When developing your own project don't forget to change it!

## > Environments:

<table border="0">
    <tr>
    <td>android-dev</td>
    <td>bevy-dev</td>
    </tr>
    <tr>
    <td>gcc-dev</td>
    <td>go-dev</td>
    </tr>
    <tr>
    <td>godot-dev</td>
    <td>haskell-dev</td>
    </tr>
    <tr>
    <td>heaps-dev</td>
    <td>java-dev</td>
    </tr>
    <tr>
    <td>node-dev</td>
    <td>ocaml-dev</td>
    </tr>
    <tr>
    <td>python-dev</td>
    <td>reactnative-dev</td>
    </tr>
    <tr>
    <td>rust-dev</td>
    <td>wordpress-dev</td>
    </tr>
</table>
