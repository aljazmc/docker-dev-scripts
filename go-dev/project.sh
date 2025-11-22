#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        .cache \
        docker-compose.yml \
        main \
        main.go

}

compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    golang:
        image: golang:latest
        working_dir: /usr/src/app
        volumes:
            - .:/usr/src/app
            - .cache:/.cache
EOF
fi

}

composehack() {

    if  ! grep -q "user" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

golang() {

if [[ ! -d .cache ]]; then

    mkdir -p .cache

fi

if [[ ! -f main.go ]]; then
    cat<<EOF > main.go
package main

import "fmt"

func main() {
    fmt.Println("Hello World!")
}
EOF
fi

    docker compose run --rm golang go build main.go
    docker compose run --rm golang sh -c "./main"
    docker compose run --rm golang sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    golang

}

"$1"
