#!/bin/bash

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script works only on GNU/Linux systems"
    exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
KVM_GID=$(stat -c %g /dev/kvm 2>/dev/null)
RENDER_GID=$(stat -c %g /dev/dri/renderD* 2>/dev/null | head -n 1)
VIDEO_GID=$(stat -c %g /dev/dri/card* 2>/dev/null | head -n 1)
AUDIO_GID=$(stat -c %g /dev/snd/controlC* 2>/dev/null | head -n 1)
GROUP_ADD=$(printf '%s\n' $KVM_GID $RENDER_GID $VIDEO_GID $AUDIO_GID | sort -un | sed '/^0\?$/d; s/.*/            - "&"/')
USER=android

CMDLINE_TOOLS_VERSION=13114758
GRADLE_VERSION=9.0.0 ## keep in sync with GRADLE_HOME and PATH in Dockerfile
KOTLIN_VERSION=2.2.21
SYSTEM_IMAGE="system-images;android-36;google_apis;x86_64"

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
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/home/$USER/.Xauthority
        environment:
            DISPLAY: $DISPLAY
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        devices:
            - /dev/dri:/dev/dri
            - /dev/kvm:/dev/kvm
            - /dev/snd:/dev/snd
${GROUP_ADD:+        group_add:
$GROUP_ADD
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
