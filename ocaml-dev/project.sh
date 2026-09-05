#!/bin/bash

## Check if OS is GNU/Linux

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

## Check if Docker compose plugin is installed

if [[ ! -x "$(command -v compose)" ]]; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
USER=ocaml

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

start() {

if [[ ! -f docker-compose.yml ]]; then
    cat <<-EOF > docker-compose.yml
services:
    ocaml:
        build: .
        user: $PROJECT_UID:$PROJECT_GID
        working_dir: /home/$USER
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
            - ~/.Xauthority:/root/.Xauthority
        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

if [ ! -d .opam ]; then

   docker compose run --rm ocaml sh -c " \
        yes | opam init --disable-sandboxing \
        && yes | opam config list \
        && yes | opam install core \
	&& echo "test -r '/home/ocaml/.opam/opam-init/init.sh' && . '/home/ocaml/.opam/opam-init/init.sh' > /dev/null 2> /dev/null || true" >> ~/.profile \
        && dune init proj helloworld"

fi

    docker compose run --rm ocaml sh -c "cd helloworld \
        && dune build \
        && dune exec helloworld \
        && printenv"

}

"$1"
