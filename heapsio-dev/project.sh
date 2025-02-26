#!/bin/bash

## Checks if docker compose is installed

if [[ ! -x "$(command -v compose version)" ]]; then
  echo "Compose plugin is not installed. Exiting..."
  exit
fi

## Variables

#PROJECT_NAME=`echo ${PWD##*/}` ## PROJECT_NAME = parent directory
PROJECT_UID=$(id -u)
PROJECT_GID=$(id -g)

## Functions

clean() {

  docker compose down -v --rmi all --remove-orphans
  rm -rf \
    .cache \
    .config \
    compile.hxml \
    docker-compose.yml \
    Dockerfile \
    hello.hl \
    .haxelib \
    haxelib \
    src

}

start() {

  mkdir -p src haxelib

if [[ ! -f compile.hxml ]]; then
  cat <<-EOF > compile.hxml
-cp src
-lib heaps
-lib hlsdl
-hl hello.hl
-main Main
EOF
fi

if [[ ! -f Dockerfile ]]; then
  cat <<EOF > Dockerfile
FROM haxe:latest

ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/haxelib:/usr/lib/haxe/lib"

RUN apt-get update && apt-get install -y --no-install-recommends \
  g++ \
  libglu1-mesa-dev \
  libmbedtls-dev \
  libopenal-dev \
  libpng-dev \
  libsdl2-dev \
  libsqlite3-dev \
  libturbojpeg-dev \
  libuv1-dev \
  libvorbis-dev \
  make \
  sudo && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /usr/src/hashlink /usr/lib/haxe/lib && \
  cd /usr/src && \
  git clone https://github.com/HaxeFoundation/hashlink && \
  cd hashlink && \
  make && \
  make install

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
  cat <<-EOF > docker-compose.yml
services:
  heapsio-dev:
    build: .
    working_dir: /home/$USER
    environment:
      DISPLAY: $DISPLAY
      XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR
    volumes:
      - .:/home/$USER
      - ./haxelib:/usr/lib/haxe/lib
      - /tmp/.X11-unix:/tmp/.X11-unix
      - /run/user/${PROJECT_UID}:/run/user/${PROJECT_UID}
      - /var/lib/dbus/machine-id:/var/lib/dbus/machine-id
      - ~/.Xauthority:/root/.Xauthority
    devices:
      - /dev/dri:/dev/dri
      - /dev/snd:/dev/snd
    network_mode: host
EOF

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Adding user configuration line to docker-compose.yml for GNU/Linux users."
    sed -i "3 a \ \ \ \ user\:\ $PROJECT_UID\:$PROJECT_GID" docker-compose.yml
  fi

fi

if [[ ! -f src/Main.hx ]]; then
  cat <<-EOF > src/Main.hx
class Main extends hxd.App {
  override function init() {
    var tf = new h2d.Text(hxd.res.DefaultFont.get(), s2d);
    tf.text = "Hello Hashlink !";
  }
  static function main() {
    new Main();
  }
}
EOF
fi

[ ! -d haxelib/heaps ]      && docker compose run --rm heapsio-dev bash -c "haxelib setup && haxelib install heaps"
[ ! -d haxelib/hlopenal ]   && docker compose run --rm heapsio-dev bash -c "haxelib install hlopenal"
[ ! -d haxelib/hlsdl ]      && docker compose run --rm heapsio-dev bash -c "haxelib install hlsdl"
[ ! -d haxelib/hldx ]       && docker compose run --rm heapsio-dev bash -c "haxelib install hldx"

docker compose run --rm heapsio-dev sh -c "printenv"
docker compose run --rm heapsio-dev haxe compile.hxml
docker compose run --rm heapsio-dev hl hello.hl

}

"$1"
