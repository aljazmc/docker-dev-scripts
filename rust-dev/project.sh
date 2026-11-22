#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
USER=rust

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans

    find . -mindepth 1 -maxdepth 1 \
        | sed "
            /Dockerfile/d;
            /project.sh/d;
            /README.md/d;
        " \
        | xargs -I {} rm -rf {}

}

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        cat << EOF > docker-compose.yml
services:
    rust:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

rust() {

    if [[ ! -f hello.rs ]]; then
        cat << EOF > hello.rs
fn main() {
    println!("Hello World!");
}
EOF
    fi

    docker compose run --rm rust sh -c " \
        rustup default stable \
        && rustc hello.rs \
        && ./hello \
        && printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    rust

}

"$1"
