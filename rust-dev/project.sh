#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        docker-compose.yml \
        hello \
        hello.rs

}

compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    rust:
        image: rust:latest
        working_dir: /usr/src/app
        volumes:
            - .:/usr/src/app
EOF
fi

}

composehack() {

    if  ! grep -q "user" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

rust() {

if [[ ! -f hello.rs ]]; then
    cat<<EOF > hello.rs
fn main() {
    println!("Hello World!");
}
EOF
fi

    docker compose run --rm rust rustc hello.rs
    docker compose run --rm rust sh -c "./hello"
    docker compose run --rm rust sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    rust

}

"$1"
