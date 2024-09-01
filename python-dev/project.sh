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
    python-dev:
        image: python:latest
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /usr/src/app
        volumes:
            - .:/usr/src/app
EOF
fi

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        __pycache__ \
        docker-compose.yml \
        hello.py

}

python() {

if [ ! -f hello.py ]; then
    cat<<EOF > hello.py
print('Hello, world!')
EOF
fi

    docker compose run --rm python-dev sh -c "python -m py_compile hello.py"
    docker compose run --rm python-dev sh -c "python __pycache__/hello.cpython-313.pyc"
    docker compose run --rm python-dev sh -c "printenv"

}

