#!/bin/bash

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes 
    rm -rf \
        .cache \
        .cargo \
       	.rustup \
	.Xauthority \
        Dockerfile \
        bevy \
        docker-compose.yml

}

compose() {

if [[ ! -f Dockerfile ]]; then
    cat <<EOF > Dockerfile
FROM debian:latest

ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    g++ \
    git \
    pkg-config \
    libx11-dev \
    libxi-dev \
    libasound2-dev \
    libudev-dev \
    libxcursor1 \
    libxkbcommon-x11-0 \
    libwayland-dev \
    libxkbcommon-dev \
    mesa-vulkan-drivers \
    rustup \
    sudo

RUN groupadd -g $PROJECT_GID -r $USER
RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER

#Change password
RUN echo "$USER:$USER" | chpasswd
#Make sudo passwordless
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER

USER $USER
WORKDIR /home/$USER

CMD ["/bin/bash"]
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
    cat << EOF > docker-compose.yml
services:
    rust:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/$PROJECT_UID:/run/user/$PROJECT_UID
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/home/$USER/.Xauthority
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        devices:
            - /dev/dri:/dev/dri
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

}

composehack() {

    if  ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

rust() {

    docker compose run --rm rust sh -c "rustup default stable"
    docker compose run --rm rust sh -c "git clone https://github.com/bevyengine/bevy \
	    && cd bevy && \
	    git checkout latest"
    docker compose run --rm rust sh -c "cd bevy \
	    && cargo run --features x11 --example hello_world"
    docker compose run --rm rust sh -c "printenv"

}

start() {

    compose

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then

        composehack

    fi

    rust

}

"$1"
