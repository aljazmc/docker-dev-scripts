#!/bin/bash

## Variables

KVMOWNER=$(ls -l /dev/kvm | awk '{print $3}');
#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)
SDK=$(echo /home/"$USER"/sdk)

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script works only on GNU/Linux systems"
    exit
fi

if [[ "$KVMOWNER" != "$USER" ]]; then 
    echo "'/dev/kvm' is not owned by the current user. Aborting..."
    exit
fi

## Functions

clean() {

    docker compose down -v --rmi all --remove-orphans
    docker system prune -af --volumes
    rm -rf \
        .android \
        app \
        .cache \
        .config \
        docker-compose.yml \
        Dockerfile \
        .emulator_console_auth_token \
        .gradle \
        .knownPackages \
        .kotlin \
        .npm \
        sdk \
        .temp \
        .yarn \
        .wget-hsts \
        ./*.zip

}

start() {

    mkdir -p app sdk/cmdline-tools

if [[ ! -f Dockerfile ]]; then
  cat <<EOF > Dockerfile
FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    default-jdk \
    libpulse-dev \
    libxcb-cursor-dev \
    libxkbfile-dev \
    libfontconfig1-dev \
    libfreetype-dev \
    libgtk-3-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxcb-cursor-dev \
    libxcb-glx0-dev \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xkb-dev \
    libxcb1-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxrender-dev \
    qemu-system-x86 \
    sudo \
    tar \
    udev \
    unzip \
    wget \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN cd /opt/ && \
    wget https://nodejs.org/dist/v24.11.1/node-v24.11.1-linux-x64.tar.xz && \
    tar xf node-v24.11.1-linux-x64.tar.xz

RUN groupadd -g $PROJECT_GID -r $USER
RUN useradd -u $PROJECT_UID -g $PROJECT_GID --create-home -r $USER

#Change password
RUN echo "$USER:$USER" | chpasswd
#Make sudo passwordless
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
RUN usermod -aG sudo $USER
RUN usermod -aG kvm $USER

USER $USER
WORKDIR /home/$USER

CMD ["/bin/bash"]
EOF
fi

if [[ ! -f docker-compose.yml ]]; then
  cat <<-EOF > docker-compose.yml
services:
    androidsdk:
        build: .
        working_dir: /home/$USER
        user: $PROJECT_UID:$PROJECT_GID
        environment:
            ANDROID_HOME: $SDK
            ANDROID_USER_HOME: /home/$USER/.android
            ANDROID_SDK_ROOT: $SDK
            DISPLAY: $DISPLAY
            GRADLE_HOME: $SDK/gradle-9.0.0/bin
            GRADLE_USER_HOME: /home/$USER/.gradle
            PATH: "/home/$USER/app:$SDK/build-tools/36.0.0:$SDK/gradle-9.0.0/bin:$SDK/kotlinc/bin:$SDK/emulator:$SDK/cmdline-tools/latest/bin:$SDK/platform-tools:/opt/node-v24.11.1-linux-x64/bin:\$PATH"
            XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
        volumes:
            - .:/home/$USER
            - /tmp/.X11-unix:/tmp/.X11-unix
            - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
            - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
            - ~/.Xauthority:/root/.Xauthority
        devices:
            - /dev/dri:/dev/dri
            - /dev/kvm:/dev/kvm
            - /dev/snd:/dev/snd
        network_mode: host
EOF
fi

    docker compose run --rm androidsdk sh -c "wget https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip && \
        unzip commandlinetools-linux-*_latest.zip cmdline-tools/* -d sdk/cmdline-tools && \
        cd sdk/cmdline-tools && \
        mv cmdline-tools latest && \
        rm ../../commandlinetools-linux-*_latest.zip"
    docker compose run --rm androidsdk sh -c "wget https://services.gradle.org/distributions/gradle-9.0.0-bin.zip && \
        unzip gradle-9.0.0-bin.zip -d sdk && \
        rm gradle-*-bin.zip"
    docker compose run --rm androidsdk sh -c "wget https://github.com/JetBrains/kotlin/releases/download/v2.2.21/kotlin-compiler-2.2.21.zip && \
        unzip kotlin-compiler-2.2.21.zip -d sdk && \
        rm kotlin-compiler-*.zip"
    docker compose run --rm androidsdk sh -c "yes | sdkmanager --licenses"
    docker compose run --rm androidsdk sh -c "sdkmanager --update && \
        sdkmanager \
            'build-tools;36.0.0' \
            'cmake;3.22.1' \
            'emulator' \
            'ndk;27.1.12297006' \
            'platform-tools' \
            'platforms;android-36' \
            'system-images;android-36;google_apis;x86_64' "
    docker compose run --rm androidsdk sh -c "echo 'no' | avdmanager create avd -n 1 -k 'system-images;android-36;google_apis;x86_64'"

    if [[ "$DESKTOP_SESSION" = "mate" ]]; then

        mate-terminal -- sh -c "docker compose run --rm androidsdk sh -c 'yes | npx @react-native-community/cli init app'"
        sleep 60
        mate-terminal -- sh -c "docker compose run --rm androidsdk sh -c 'emulator -avd 1'"
        sleep 60
        mate-terminal -- sh -c "docker compose run --rm androidsdk sh -c 'cd app && node_modules/.bin/react-native start'"
        sleep 60
        mate-terminal -- sh -c "docker compose run --rm androidsdk sh -c 'cd app && npx react-native run-android'"

    else 

        echo "Install mate-terminal to be able to start this development environment!"

    fi

}

"$1"
