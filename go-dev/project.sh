#!/bin/bash

## Check for linux and docker compose or quit

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Configuration files

# docker-compose.yml
if [ ! -f docker-compose.yml ]; then
    cat << EOF > docker-compose.yml
services:
    golang:
        image: golang:latest
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /usr/src/app
        volumes:
            - .:/usr/src/app
            - .cache:/.cache
EOF
fi

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        .cache \
        docker-compose.yml \
        main \
        main.go

}

golang() {

if [ ! -d .cache ]; then
    mkdir -p .cache
fi
if [ ! -f main.go ]; then
    cat<<EOF > main.go
package main

import "fmt"

func main() {
    fmt.Println("Hello World!")
}
EOF
fi

    docker compose run --rm golang sh -c "printenv"
    docker compose run --rm golang go build main.go
    docker compose run --rm golang sh -c "./main"

}

start() {

    golang

}

"$1"
