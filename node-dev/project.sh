#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        dist \
        docker-compose.yml \
        node_modules \
        package.json \
        yarn.lock \
        .cache \
        .pnp.cjs \
        .pnp.loader.mjs \
        .vim \
        .vimrc \
        .yarn/berry \
        .yarn/bin \
        .yarn/sdks \
        .yarn/unplugged \
        .yarn/install-state.gz \
        .yarnrc

}


compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    node:
        image: node:current-alpine
        working_dir: "$PWD"
        volumes:
            - .:$PWD
        environment:
            HOME:               "$PWD"
            NODE_ENV:           development
        network_mode: host
EOF
fi

}

composehack() {

    if  ! grep -q "user" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

node() {

if [[ ! -f package.json ]]; then

    docker compose run --rm node yarn init

else

    docker compose run --rm node yarn install

fi

docker compose run --rm node sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    node

}

"$1"
