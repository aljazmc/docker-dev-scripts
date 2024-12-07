# docker-dev-scripts
Miscellaneous scripts to quickly set-up dockerized development environments.

## > Requirements:

* GNU/Linux operating system
* docker compose

## > Basic usage

Use case for node development environment:

* clone the project with:
```
git clone https://github.com/aljazmc/docker-scripts
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
> Adjust clean() function before using it because the default setting is to delete all default generated files by project.sh. This is optimal for project.sh development but less useful for your own project.

## > Environments:

<ul>
    <strong>
    <li>gcc-dev</li>
    <li>go-dev</li>
    <li>haskell-dev</li>
    <li>heapsio-dev</li>
    <li>java-dev</li>
    <li>node-dev</li>
    <li>ocaml-dev</li>
    <li>python-dev</li>
    <li>rust-dev</li>
    <li>wordpress-dev</li>
    </strong>
</ul>

## > LICENSE: [MIT](https://github.com/aljazmc/docker-scripts/blob/main/LICENSE)
