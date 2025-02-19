[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

# docker-dev-scripts
Miscellaneous scripts to quickly set-up dockerized development environments
&nbsp;

&nbsp;

## > Prerequisites

* Linux system with bash shell
* Docker (with docker compose plugin) installed and running
&nbsp;

&nbsp;

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
&nbsp;

&nbsp;

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
&nbsp;

&nbsp;

