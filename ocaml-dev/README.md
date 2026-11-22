# ocaml-dev

Dockerized development environment for [OCaml](https://ocaml.org) with [opam](https://opam.ocaml.org) and [Dune](https://dune.build).

## > Usage

```
./project.sh start      # build the image, set up opam, generate, build and run the project
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`project.sh` runs only on GNU/Linux. `./project.sh start`:

1. generates `docker-compose.yml` with your user and group id, so generated files are owned by you
2. on the first run initializes opam in `.opam/` and installs the `core` library
3. creates the `helloworld` project with `dune init proj` if it does not exist
4. builds it with `dune build`, runs it with `dune exec helloworld` and prints the container's environment variables

Existing files are not overwritten, so you can develop your own project in their place.

## > Image

Based on `debian:13.7` with `ocaml`, `ocaml-dune` and `opam`, the version control tools opam uses (git, mercurial, darcs, rsync), and the X11, OpenGL, Vulkan, SDL3 and OpenAL libraries graphical programs need.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm ocaml bash
```

## > GPU

`docker-compose.yml` is generated on the first run and passes the host's GPU to the `ocaml` container if one exists:

* Intel and AMD (Mesa): `/dev/dri` is mapped into the container. On laptops with an additional AMD GPU, `DRI_PRIME` selects it.
* NVIDIA (proprietary driver): requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. The GPU is reserved for the container and selected for OpenGL and Vulkan, also on laptops with PRIME render offload. Without the toolkit, `project.sh` prints a warning and the container falls back to the other GPU or to software rendering.

Windows use the host's X server (`DISPLAY`, `/tmp/.X11-unix` and the X authority file, `$XAUTHORITY` or else `~/.Xauthority`, mounted at the same path) and sound the host's PipeWire/PulseAudio (`/run/user/<uid>`). `docker compose` reads `DISPLAY` and `XAUTHORITY` each time it starts the container, so the file keeps working after you log in again. The X authority file, `/etc/machine-id`, `/dev/dri` and `/dev/snd` are mounted only if they exist on the host.

The file is not regenerated, so delete `docker-compose.yml` after adding or removing a GPU or installing the toolkit.

## > License

OCaml is free and open-source software licensed under the [GNU Lesser General Public License, version 2.1, with the OCaml static linking exception](https://github.com/ocaml/ocaml/blob/trunk/LICENSE), opam under the same license and Dune under the [MIT License](https://github.com/ocaml/dune/blob/main/LICENSE.md).
