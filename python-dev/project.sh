#!/bin/bash

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

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
    sed -i "3 a \ \ \ \ user\:\ $PROJECT_UID\:$PROJECT_GID" docker-compose.yml
  fi

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

  docker compose run --rm python-dev sh -c "printenv"
  docker compose run --rm python-dev sh -c "python -m py_compile hello.py"
  docker compose run --rm python-dev sh -c "python __pycache__/hello.cpython-313.pyc"

}

start() {

  python

}

"$1"
