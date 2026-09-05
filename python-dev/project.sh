#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=python

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
    python:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
EOF
fi

}

composehack() {

    if  ! grep -q "user" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

python() {

if [[ ! -f hello.py ]]; then
    cat<<EOF > hello.py
print('Hello, world!')
EOF
fi

    docker compose run --rm python sh -c " \
        python3 -m py_compile hello.py \
        && python3 __pycache__/hello.cpython-313.pyc \
        && printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    python

}

"$1"
