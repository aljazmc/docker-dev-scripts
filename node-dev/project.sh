#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        Dockerfile \
        README.md \
        dist \
        docker-compose.yml \
        node_modules \
        package.json \
        yarn.lock \
        .cache \
        .editorconfig \
        .gitattributes \
        .gitignore \
        .git \
        .npm \
        .pnp.cjs \
        .pnp.loader.mjs \
        .vim \
        .vimrc \
        .yarn \
        .yarn/berry \
        .yarn/bin \
        .yarn/sdks \
        .yarn/unplugged \
        .yarn/install-state.gz \
        .yarnrc \
        .yarnrc.yml

}


compose() {

if [[ ! -f Dockerfile ]]; then
    cat << EOF > Dockerfile
FROM node:current-alpine

RUN apk update && \
    apk add git && \
    npm install -g corepack
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    node:
        build: .
        working_dir: $PWD
        volumes:
            - .:$PWD
        environment:
            COREPACK_ENABLE_DOWNLOAD_PROMPT: 0
            HOME:                            "$PWD"
            NODE_ENV:                        development
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

    docker compose run --rm node yarn init -y

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
