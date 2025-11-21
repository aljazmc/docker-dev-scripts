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
        main \
        main.c

}

compose() {

if [ ! -f docker-compose.yml ]; then
    cat << EOF > docker-compose.yml
services:
    gcc:
        image: gcc:latest
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

    docker compose run --rm gcc gcc main.c -o main
    docker compose run --rm gcc sh -c "./main"
    docker compose run --rm gcc sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    gcc

}

"$1"
