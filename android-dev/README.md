# android-dev

Dockerized development environment for [Android](https://developer.android.com) apps in [Kotlin](https://kotlinlang.org) with [Jetpack Compose](https://developer.android.com/compose), built with [Gradle](https://gradle.org).

## > Usage

```
./project.sh start      # build the image, download the SDK, generate, build and install the app in the emulator
./project.sh clean      # remove the containers, images, volumes and all generated files
```

The host needs `/dev/kvm` (hardware virtualization enabled) for the emulator, and `mate-terminal`, in which the emulator is started.

`./project.sh start`:

1. generates `docker-compose.yml` (on GNU/Linux with your user and group id, so generated files are owned by you)
2. on the first run downloads into `sdk/`: the Android command-line tools, Gradle and the Kotlin compiler (`CMDLINE_TOOLS_VERSION`, `GRADLE_VERSION`, `KOTLIN_VERSION` in `project.sh`), and with `sdkmanager` the build tools, platform tools, CMake, NDK, emulator, the `android-36` platform and the `SYSTEM_IMAGE` system image. It then creates an Android virtual device named `1`.
3. creates the app in `app/` with `gradle init` if it does not exist yet and replaces the generated files with an Android app (`org.example`) that shows "Hello world!"
4. starts the emulator in a new `mate-terminal` window, then builds the app with `gradlew build`, installs it with `gradlew installDebug` and starts it with `adb`

`GRADLE_VERSION` in `project.sh` must match `GRADLE_HOME` and `PATH` in `Dockerfile`.

## > Image

Based on `debian:13.7` with `default-jdk`, QEMU, `android-udev-rules` and the X11, sound and GPU libraries the emulator needs. The container uses the host's network and gets `/dev/kvm` and `/dev/snd`.

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

The Android Open Source Project is free and open-source software released mostly under the [Apache License 2.0](https://source.android.com/docs/setup/about/licenses). The prebuilt Android SDK packages that `sdkmanager` downloads are covered by the [Android Software Development Kit License Agreement](https://developer.android.com/studio/terms), which `project.sh` accepts for you with `sdkmanager --licenses`, so read it before using this environment. Kotlin is released under the [Apache License 2.0](https://github.com/JetBrains/kotlin/blob/master/license/LICENSE.txt).
