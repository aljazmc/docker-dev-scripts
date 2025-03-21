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
    Dockerfile \
    hello.ml \
    helloworld \
    .opam

}

start() {

if [ ! -f docker-compose.yml ]; then
  cat <<-EOF > docker-compose.yml
services:
  ocamlopam:
    image: ocaml/opam:debian
    working_dir: /home/$USER
    command: /bin/sh -c "opam init --root=/home/$USER/.opam"
    volumes:
      - .:/home/$USER
    network_mode: host
EOF

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
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
    sed -i "11a \ $volumes"  docker-compose.yml
    sed -i "14a \ $devices"  docker-compose.yml
  fi
  
fi

if [ ! -d .opam ]; then
opamroot="$(cat <<-EOT
     OPAMROOT: /home/$USER/.opam
EOT
)"
opamrootwithenv="$(cat <<-EOT
    environment:\\
      OPAMROOT: /home/$USER/.opam
EOT
)"


  docker compose run --rm ocamlopam

  if grep "OPAMROOT" docker-compose.yml
  then
    echo "\$OPAMROOT is already present in docker-compose.yml"
  else
    if grep "environment" docker-compose.yml
    then
      echo "adding \$OPAMROOT to docker-compose.yml"
      sed -i "7a \ $opamroot" docker-compose.yml
    else
      echo "adding \$OPAMROOT with environment to docker-compose.yml"
      sed -i "5a \ $opamrootwithenv" docker-compose.yml
    fi
  fi

  docker compose run --rm ocamlopam opam config list
  docker compose run --rm ocamlopam opam install core
  docker compose run --rm ocamlopam dune init proj helloworld

fi

  docker compose run --rm ocamlopam sh -c "printenv"
  docker compose run --rm ocamlopam sh -c "cd helloworld && dune build"
  docker compose run --rm ocamlopam sh -c "cd helloworld && dune exec helloworld"

}

"$1"
