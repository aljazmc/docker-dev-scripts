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
  rust:
    image: rust:latest
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
    docker-compose.yml \
    hello \
    hello.rs

}

rust() {

if [ ! -f hello.rs ]; then
  cat<<EOF > hello.rs
fn main() {
  println!("Hello World!");
}
EOF
fi

  docker compose run --rm rust sh -c "printenv"
  docker compose run --rm rust rustc hello.rs
  docker compose run --rm rust sh -c "./hello"

}

start() {

  rust

}

