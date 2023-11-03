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
    gcc:
        image: gcc:latest
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
        main \
        main.c

}

gcc() {

if [ ! -f main.c ]; then
    cat<<EOF > main.c
#include <stdio.h>

int main(void)
{
    int i;
    printf("Hello world!\n");
}
EOF
fi

    docker compose run --rm gcc sh -c "printenv"
    docker compose run --rm gcc gcc main.c -o main
    docker compose run --rm gcc sh -c "./main"

}

start() {

    gcc

}

"$1"
