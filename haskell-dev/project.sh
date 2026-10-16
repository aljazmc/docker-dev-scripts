#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=haskell

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    haskell:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
EOF
    fi

}

composehack() {

    if ! grep -q "user" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

haskell() {

    if [[ ! -f helloworld.hs ]]; then
        cat << EOF > helloworld.hs
main :: IO ()
main = putStrLn "Hello, World!"
EOF
    fi

    docker compose run --rm haskell sh -c " \
        stack ghc helloworld.hs \
        && ./helloworld \
        && printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    haskell

}

"$1"
