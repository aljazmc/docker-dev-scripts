[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# docker-dev-scripts
Scripts to quickly setup dockerized development environments

## > Features

* **fully automated setup**
* **simple one-command start:** with `./project.sh start`.
* **simple one-command cleanup:** with `./project.sh clean`.

> [!CAUTION]
> Function "clean" is used in development of "project.sh" to remove **ALL** files and folders. When developing your own project don't forget to tweak it when necessary!

## > Prerequisites

* Linux system with bash shell
* Docker (with docker compose plugin) installed and running

## > Example

Use case for node development environment:

```
## clone the project with:
git clone https://github.com/aljazmc/docker-dev-scripts

## move to the desired subdirectory:
cd node-dev

## download and setup everything necessary with:
./project.sh start

## after use you can quickly clean up with: 
./project.sh clean
```

> [!CAUTION]
> Function "clean" is used in development of "project.sh" to remove **ALL** files and folders. When developing your own project don't forget to tweak it when necessary!

## > Environments:

<table border="0">
    <tr>
    <td>gcc-dev</td>
    <td>go-dev</td>
    </tr>
    <tr>
    <td>haskell-dev</td>
    <td>heapsio-dev</td>
    </tr>
    <tr>
    <td>java-dev</td>
    <td>node-dev</td>
    </tr>
    <tr>
    <td>ocaml-dev</td>
    <td>python-dev</td>
    </tr>
    <tr>
    <td>rust-dev</td>
    <td>wordpress-dev</td>
    </tr>
</table>
