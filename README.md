[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# docker-dev-scripts
Miscellaneous scripts to quickly set-up dockerized development environments

## > Prerequisites

* Linux system with bash shell
* Docker (with docker compose plugin) installed and running

## > How to use docker-dev-scripts

Use case for node development environment:

* clone the project with:
```
git clone https://github.com/aljazmc/docker-dev-scripts
```
* move to the desired subdirectory:
```
cd node-dev
```
* download and setup everything necessary with:
```
./project.sh start
```
* after use you can quickly clean up with: 
```
./project.sh clean
```

> [!CAUTION]
> Function "clean" is used in development of "project.sh" to remove configuration/cached/dependencies files and folders. When developing your own project use it carefully and don't forget to change it if necessary!

