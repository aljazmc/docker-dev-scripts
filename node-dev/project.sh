#!/bin/bash

## Check for linux and docker compose or quit

if ! (( "$OSTYPE" == "gnu-linux" )); then
  echo "Script runs only on GNU/Linux OS. Exiting..."
  exit
fi

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## Variables

PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=`id -u`
PROJECT_GID=`id -g`

## Configuration files

# docker-compose.yml
if [ ! -f docker-compose.yml ]; then
  cat << EOF > docker-compose.yml
  services:
    node:
      image: node:current-alpine
      user: $PROJECT_UID:$PROJECT_GID
      working_dir: /home/node
      volumes:
        - .:/home/node
      environment:
        NODE_ENV:   development
        PATH:     "/home/node/.yarn/bin:/home/node/node_modules/.bin:\$PATH"
      network_mode: host
EOF
fi

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    node_modules \
    .cache \
    .npm \
    .yarn/berry \
    .yarn/bin \
    .yarn/unplugged \
    .yarn/install-state.gz

}

node() {

  if [ ! -f package.json ]; then
    docker compose run node yarn init
  else
    docker compose run node yarn install
  fi

  docker compose run node sh -c "printenv"

}

start() {

  node

}

"$1"
