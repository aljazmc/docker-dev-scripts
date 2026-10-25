FROM debian:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    USER=haskell

ENV LANG=C \
    LC_ALL=C \
    PATH="$PATH:/home/$USER"

RUN <<'EOF'
runtimeDeps=(
    ca-certificates
    sudo
)
libraries=(
    g++
    haskell-stack
)
apt-get update
apt-get install --no-install-recommends ${runtimeDeps[@]} ${libraries[@]} -y
apt-get dist-clean

groupadd --gid 1000 $USER
useradd --uid 1000 --gid $USER --shell /bin/bash --create-home $USER
echo "$USER:$USER" | chpasswd
echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$USER
EOF

USER $USER
WORKDIR /home/$USER

CMD [ "bash" ]

