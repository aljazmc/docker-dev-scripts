#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    rm -rf \
        docker-compose.yml \
        helloworld \
        helloworld.hi \
        helloworld.hs \
        helloworld.o

}

compose() {

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    haskell:
        image: haskell:latest
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
        network_mode: host
EOF
fi

}

composehack() {

devices="$(cat <<-EOT
       devices:\\
            - /dev/dri:/dev/dri\\
            - /dev/snd:/dev/snd
EOT
)"
environment="$(cat <<-EOT
       environment:\\
            DISPLAY: $DISPLAY\\
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
EOT
)"
user="$(cat <<-EOT
       user: $PROJECT_UID:$PROJECT_GID
EOT
)"
volumes="$(cat <<-EOT
           - /tmp/.X11-unix:/tmp/.X11-unix\\
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}\\
            - ~/.Xauthority:/root/.Xauthority
EOT
)"

    echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
    sed -i "3a \ $user" docker-compose.yml
    sed -i "5a \ $environment"  docker-compose.yml
    sed -i "10a \ $volumes"  docker-compose.yml
    sed -i "13a \ $devices"  docker-compose.yml

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    if [[ ! -f helloworld.hs ]]; then
        cat <<-EOF > helloworld.hs
main :: IO ()
main = putStrLn "Hello, World!"
EOF
    fi

    docker compose run --rm haskell ghc helloworld.hs
    docker compose run --rm haskell sh -c "./helloworld"
    docker compose run --rm haskell sh -c "printenv"

}

"$1"
