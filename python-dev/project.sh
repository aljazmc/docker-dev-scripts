#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        __pycache__ \
        docker-compose.yml \
        hello.py

}

compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    python-dev:
        image: python:latest
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

python() {

if [[ ! -f hello.py ]]; then
    cat<<EOF > hello.py
print('Hello, world!')
EOF
fi

    docker compose run --rm python-dev sh -c "python -m py_compile hello.py"
    docker compose run --rm python-dev sh -c "python __pycache__/hello.cpython-314.pyc"
    docker compose run --rm python-dev sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    python

}

"$1"
