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
    rust:
        image: rust:latest
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /usr/src/app
        volumes:
            - .:/usr/src/app
EOF
fi

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        docker-compose.yml \
        hello \
        hello.rs

}
