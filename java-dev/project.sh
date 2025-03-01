#!/bin/bash

## Check for linux

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo "Script runs only on GNU/Linux OS. Exiting..."
  exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Configuration files

# Dockerfile

# docker-compose.yml
if [ ! -f docker-compose.yml ]; then
  cat << EOF > docker-compose.yml
services:
  java-compiler:
    image: eclipse-temurin:22-alpine
    user: $PROJECT_UID:$PROJECT_GID
    working_dir: /opt/app
    volumes:
      - .:/opt/app
EOF
fi

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    docker-compose.yml \
    HelloWorld.class \
    HelloWorld.java

}

runjava() {

if [ ! -f HelloWorld.java ]; then
  cat<<EOF > HelloWorld.java
public class HelloWorld {
  public static void main(String[] args) {
    // Prints "Hello, World" in the terminal window.
    System.out.println("Hello, World");
  }
}
EOF
fi

  docker compose run --rm java-compiler sh -c "printenv"
  docker compose run --rm java-compiler javac HelloWorld.java
  docker compose run --rm java-compiler java HelloWorld

}

start() {

  runjava

}

"$1"
