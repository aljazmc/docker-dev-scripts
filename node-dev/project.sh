#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=node

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
    node:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
        environment:
            COREPACK_ENABLE_DOWNLOAD_PROMPT: 0
            HOME:                            /home/$USER
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
