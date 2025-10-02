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
> Function "clean" is used in development of "project.sh" to remove **ALL** generated files and folders. When developing your own project don't forget to change it!

## > Environments:

<table border="0">
    <tr>
    <td>androidsdk-dev</td>
    <td>gcc-dev</td>
    </tr>
    <tr>
    <td>go-dev</td>
    <td>haskell-dev</td>
    </tr>
    <tr>
    <td>heapsio-dev</td>
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
