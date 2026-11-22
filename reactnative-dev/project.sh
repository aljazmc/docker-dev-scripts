#!/bin/bash

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script works only on GNU/Linux systems"
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
PROJECT_GROUPS=$({ id -G; stat -c %g /dev/dri/* /dev/kvm /dev/snd/*; } 2>/dev/null | tr ' ' '\n' | sort -un \
    | sed "/^0\?$/d; /^$PROJECT_GID$/d" | sed 's/.*/\\n\\1    - "&"/' | tr -d '\n') ## your groups and those of the GPU, KVM and sound devices, as group_add lines for composehack
AMD_GPU=$(grep -l 0x1002 /sys/class/drm/renderD*/device/vendor 2>/dev/null | head -n 1)
AMD_PRIME=${AMD_GPU:+pci-$(basename "$(readlink -f "${AMD_GPU%/vendor}")" | tr :. __)}
DRI_DEVICE=$(ls -d /dev/dri 2>/dev/null)
SND_DEVICE=$(ls -d /dev/snd 2>/dev/null)
MACHINE_ID=$(find /etc/machine-id /var/lib/dbus/machine-id -maxdepth 0 2>/dev/null | head -n 1)
XAUTH=$(ls "${XAUTHORITY:-$HOME/.Xauthority}" 2>/dev/null) ## mounted only if it exists, as Docker would create a directory in its place
# shellcheck disable=SC2016 ## left to docker compose, which reads XAUTHORITY and HOME whenever it starts the container
XAUTH_PATH='${XAUTHORITY:-$HOME/.Xauthority}'
NVIDIA_GPU=$(ls /dev/nvidiactl 2>/dev/null)
NVIDIA_TOOLKIT=$(command -v nvidia-container-runtime-hook)
NVIDIA=${NVIDIA_GPU:+${NVIDIA_TOOLKIT:+yes}}
USER=android

CMDLINE_TOOLS_VERSION=13114758
GRADLE_VERSION=9.0.0 ## keep in sync with GRADLE_HOME and PATH in Dockerfile
KOTLIN_VERSION=2.2.21
SYSTEM_IMAGE="system-images;android-36;google_apis;x86_64"

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
        if [[ -n $NVIDIA_GPU && -z $NVIDIA_TOOLKIT ]]; then
            echo "NVIDIA GPU found, but NVIDIA Container Toolkit is not installed. The container will not use the NVIDIA GPU."
        fi
        mkdir -p .cache
        cat << EOF > docker-compose.yml
services:
    android:
        build: .
        working_dir: /home/$USER
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/$PROJECT_UID:/run/user/$PROJECT_UID
${MACHINE_ID:+            - $MACHINE_ID:/etc/machine-id:ro
            - $MACHINE_ID:/var/lib/dbus/machine-id:ro
}${XAUTH:+            - $XAUTH_PATH:$XAUTH_PATH:ro
}        environment:
            DISPLAY: \${DISPLAY:-:0}
            XDG_RUNTIME_DIR: /run/user/$PROJECT_UID
${XAUTH:+            XAUTHORITY: $XAUTH_PATH
}${AMD_PRIME:+            DRI_PRIME: $AMD_PRIME
}${NVIDIA:+            NVIDIA_DRIVER_CAPABILITIES: all
            __NV_PRIME_RENDER_OFFLOAD: 1
            __GLX_VENDOR_LIBRARY_NAME: nvidia
            __VK_LAYER_NV_optimus: NVIDIA_only
}        devices:
${DRI_DEVICE:+            - /dev/dri:/dev/dri
}            - /dev/kvm:/dev/kvm
${SND_DEVICE:+            - /dev/snd:/dev/snd
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
        sed -i "/working_dir\:/{s@^\( \+\)@\1user\: $PROJECT_UID\:$PROJECT_GID${PROJECT_GROUPS:+\n\1group_add\:$PROJECT_GROUPS}\n\1@}" docker-compose.yml
    fi

}

sdk() {

    if [[ ! -d sdk/cmdline-tools/latest ]]; then
        mkdir -p sdk/cmdline-tools
        docker compose run --rm android sh -c " \
            wget https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
            && unzip commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip 'cmdline-tools/*' -d sdk/cmdline-tools \
            && mv sdk/cmdline-tools/cmdline-tools sdk/cmdline-tools/latest \
            && rm commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip \
            && wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
            && unzip gradle-${GRADLE_VERSION}-bin.zip -d sdk \
            && rm gradle-${GRADLE_VERSION}-bin.zip \
            && wget https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip \
            && unzip kotlin-compiler-${KOTLIN_VERSION}.zip -d sdk \
            && rm kotlin-compiler-${KOTLIN_VERSION}.zip \
            && yes | sdkmanager --licenses \
            && sdkmanager --update \
            && sdkmanager \
                'build-tools;36.0.0' \
                'cmake;3.22.1' \
                'emulator' \
                'ndk;27.1.12297006' \
                'platform-tools' \
                'platforms;android-36' \
                '$SYSTEM_IMAGE' \
            && echo 'no' | avdmanager create avd -n 1 -k '$SYSTEM_IMAGE'"
    fi

}

reactnative() {

    if ! command -v mate-terminal > /dev/null; then
        echo "Install mate-terminal to be able to start this development environment!"
        exit
    fi

    if [[ ! -f app/package.json ]]; then
        mate-terminal -- sh -c "docker compose run --rm android sh -c 'yes | npx @react-native-community/cli init app'"
        sleep 60
    fi

    mate-terminal -- sh -c "docker compose run --rm android sh -c 'emulator -avd 1'"
    sleep 60
    mate-terminal -- sh -c "docker compose run --rm android sh -c 'cd app && node_modules/.bin/react-native start'"
    sleep 60
    mate-terminal -- sh -c "docker compose run --rm android sh -c 'cd app && npx react-native run-android'"

}

start() {

    compose
    composehack
    sdk
    reactnative

}

"$1"
