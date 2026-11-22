# reactnative-dev

Dockerized development environment for [React Native](https://reactnative.dev) apps, running in the Android emulator.

## > Usage

```
./project.sh start      # build the image, download the SDK, generate the app and run it in the emulator
./project.sh clean      # remove the containers, images, volumes and all generated files
```

`project.sh` runs only on GNU/Linux. The host needs `/dev/kvm` (hardware virtualization enabled) for the emulator, and `mate-terminal`, in which the long-running steps are started.

`./project.sh start`:

1. generates `docker-compose.yml` with your user and group id, so generated files are owned by you
2. on the first run downloads into `sdk/`: the Android command-line tools, Gradle and the Kotlin compiler (`CMDLINE_TOOLS_VERSION`, `GRADLE_VERSION`, `KOTLIN_VERSION` in `project.sh`), and with `sdkmanager` the build tools, platform tools, CMake, NDK, emulator, the `android-36` platform and the `SYSTEM_IMAGE` system image. It then creates an Android virtual device named `1`.
3. creates the app in `app/` with `npx @react-native-community/cli init app` if it does not exist yet
4. starts, each in a new `mate-terminal` window and a minute apart: the emulator, the Metro bundler (`react-native start`) and `npx react-native run-android`, which builds the app and installs it in the emulator

`GRADLE_VERSION` in `project.sh` must match `GRADLE_HOME` and `PATH` in `Dockerfile`.

## > Image

Based on `debian:13.7` with Node.js (`NODE_VERSION` in `Dockerfile`, verified with the release keys), Corepack, `default-jdk`, QEMU, `android-udev-rules` and the X11, sound and GPU libraries the emulator needs. The container uses the host's network and gets `/dev/kvm` and `/dev/snd`.

A shell in the container, with this directory as the home directory:

```
docker compose run --rm android bash
```

## > GPU

`docker-compose.yml` is generated on the first run and passes the host's GPU to the `android` container if one exists:

* Intel and AMD (Mesa): `/dev/dri` is mapped into the container. On laptops with an additional AMD GPU, `DRI_PRIME` selects it.
* NVIDIA (proprietary driver): requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. The GPU is reserved for the container and selected for OpenGL and Vulkan, also on laptops with PRIME render offload. Without the toolkit, `project.sh` prints a warning and the container falls back to the other GPU or to software rendering.

Windows use the host's X server (`DISPLAY`, `/tmp/.X11-unix` and the X authority file, `$XAUTHORITY` or else `~/.Xauthority`, mounted at the same path) and sound the host's PipeWire/PulseAudio (`/run/user/<uid>`). `docker compose` reads `DISPLAY` and `XAUTHORITY` each time it starts the container, so the file keeps working after you log in again. The X authority file, `/etc/machine-id`, `/dev/dri` and `/dev/snd` are mounted only if they exist on the host.

The file is not regenerated, so delete `docker-compose.yml` after adding or removing a GPU or installing the toolkit.

## > License

React Native is free and open-source software licensed under the [MIT License](https://github.com/facebook/react-native/blob/main/LICENSE). The prebuilt Android SDK packages that `sdkmanager` downloads are covered by the [Android Software Development Kit License Agreement](https://developer.android.com/studio/terms), which `project.sh` accepts for you with `sdkmanager --licenses`, so read it before using this environment. Node.js is licensed under the [MIT License](https://github.com/nodejs/node/blob/main/LICENSE).
