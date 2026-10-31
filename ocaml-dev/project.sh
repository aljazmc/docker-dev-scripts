#!/bin/bash

## Check if OS is GNU/Linux

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "Script runs only on GNU/Linux OS. Exiting..."
    exit
fi

## Check if Docker compose plugin is installed

if ! docker compose version > /dev/null 2>&1; then
    echo "Compose plugin is not installed. Exiting..."
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
RENDER_GID=$(stat -c %g /dev/dri/renderD* 2>/dev/null | head -n 1)
VIDEO_GID=$(stat -c %g /dev/dri/card* 2>/dev/null | head -n 1)
AUDIO_GID=$(stat -c %g /dev/snd/controlC* 2>/dev/null | head -n 1)
GROUP_ADD=$(printf '%s\n' $RENDER_GID $VIDEO_GID $AUDIO_GID | sort -un | sed '/^0\?$/d; s/.*/            - "&"/')
AMD_GPU=$(grep -l 0x1002 /sys/class/drm/renderD*/device/vendor 2>/dev/null | head -n 1)
AMD_PRIME=${AMD_GPU:+pci-$(basename "$(readlink -f "${AMD_GPU%/vendor}")" | tr :. __)}
DRI_DEVICE=$(ls -d /dev/dri 2>/dev/null)
NVIDIA_GPU=$(ls /dev/nvidiactl 2>/dev/null)
NVIDIA_TOOLKIT=$(command -v nvidia-container-runtime-hook)
NVIDIA=${NVIDIA_GPU:+${NVIDIA_TOOLKIT:+yes}}
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

compose() {

    if [[ ! -f docker-compose.yml ]]; then
        if [[ -n $NVIDIA_GPU && -z $NVIDIA_TOOLKIT ]]; then
            echo "NVIDIA GPU found, but NVIDIA Container Toolkit is not installed. The container will not use the NVIDIA GPU."
        fi
        cat << EOF > docker-compose.yml
services:
    ocaml:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/$PROJECT_UID:/run/user/$PROJECT_UID
            - ~/.Xauthority:/home/$USER/.Xauthority
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
${AMD_PRIME:+            DRI_PRIME: $AMD_PRIME
}${NVIDIA:+            NVIDIA_DRIVER_CAPABILITIES: all
            __NV_PRIME_RENDER_OFFLOAD: 1
            __GLX_VENDOR_LIBRARY_NAME: nvidia
            __VK_LAYER_NV_optimus: NVIDIA_only
}        devices:
${DRI_DEVICE:+            - /dev/dri:/dev/dri
}            - /dev/snd:/dev/snd
${GROUP_ADD:+        group_add:
$GROUP_ADD
}${NVIDIA:+        deploy:
            resources:
                reservations:
                    devices:
                        - driver: nvidia
                          count: all
                          capabilities: [gpu]
}        network_mode: host
EOF
    fi

}

composehack() {

    if ! grep -q "user\:" "docker-compose.yml"; then
        echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID\n\1@}" docker-compose.yml
    fi

}

opam() {

    if [[ ! -d .opam ]]; then
        docker compose run --rm ocaml sh -c " \
            yes | opam init --disable-sandboxing \
            && yes | opam config list \
            && yes | opam install core \
            && echo \"test -r '/home/$USER/.opam/opam-init/init.sh' && . '/home/$USER/.opam/opam-init/init.sh' > /dev/null 2> /dev/null || true\" >> ~/.profile"
    fi

}

ocaml() {

    if [[ ! -d helloworld ]]; then
        docker compose run --rm ocaml sh -c "dune init proj helloworld"
    fi

    docker compose run --rm ocaml sh -c " \
        cd helloworld \
        && dune build \
        && dune exec helloworld \
        && printenv"

}

start() {

    compose
    composehack
    opam
    ocaml

}

"$1"
