# bevy-dev

Dockerized development environment for the [Bevy](https://bevy.org) game engine.

## > Usage

```
./project.sh start              # build the image, generate the crate, build and run it
./project.sh bundleforlinux     # dist/<name>-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/<name>-windows-x86_64.zip
./project.sh makebundles        # dist/<name>-linux-x86_64.sh and dist/<name>-windows-x86_64.exe from the bundles above
./project.sh clean
```

`<name>` stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `bevy-dev`. It names the crate, its binary, the bundles and the window title. Use lowercase letters, digits and dashes, as the name is used in file names, and Cargo requires it for crate names.

`./project.sh start` generates a `hello` crate that depends on bevy from crates.io and shows "Hello Bevy!" in a window. Existing files are not overwritten, so you can develop your own game in their place. Run `./project.sh start` once before bundling.

The generated project:

* `Cargo.toml` - the `<name>` package
* `src/main.rs` - sets up the app: window title and size, background color, and the game's plugins
* `src/hello.rs` - `HelloPlugin`, which spawns a camera and the text. The camera always shows a 960x540 area scaled to fit the window, so the layout does not depend on the window size. Add further features as plugins in their own modules.
* `assets/` - files for Bevy's `AssetServer`. Under `cargo run` Bevy reads it next to `Cargo.toml`, in the bundles next to the executable.

Each bundle contains the stripped release binary, renamed to `<name>` (`<name>.exe` on Windows), and the project's `assets/` folder if it exists. The Windows binary is cross-compiled with MinGW (`x86_64-pc-windows-gnu`) and linked statically, so it does not need any MinGW or Visual C++ runtime DLLs.

There is no `bundleformac`: cross-compiling for macOS requires Apple's macOS SDK, which may only be used on Apple hardware.

## > GPU

`docker-compose.yml` is generated on the first run and passes the host's GPU to the container if one exists:

* Intel and AMD (Mesa): `/dev/dri` is mapped into the container. On laptops with an additional AMD GPU, `DRI_PRIME` selects it.
* NVIDIA (proprietary driver): requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. The GPU is reserved for the container and selected for OpenGL and Vulkan, also on laptops with PRIME render offload. Without the toolkit, `project.sh` prints a warning and the container falls back to the other GPU or to software rendering.

The file is not regenerated, so delete `docker-compose.yml` after adding or removing a GPU or installing the toolkit.

## > Self-extracting bundles

`./project.sh makebundles` packs the bundles made by `bundleforlinux` and `bundleforwindows` (whichever exist) into single files that start the game directly:

* `dist/<name>-linux-x86_64.sh` is a shell script with the bundle appended as a tar.gz. It unpacks the bundle into a temporary directory, runs it and removes the directory when the game exits: `sh <name>-linux-x86_64.sh` (or `chmod +x` it and start it directly).
* `dist/<name>-windows-x86_64.exe` is a silent NSIS installer doing the same in the user's temporary directory. It needs no administrator rights.

The requirements are the same as for the bundles below. As the working directory of the game may be temporary, write files that should persist (e.g. saved games) to the user's data directory (`~/.local/share/...` or `%APPDATA%\...`) instead.

## > Running the bundles

### Linux

```
tar -xzf <name>-linux-x86_64.tar.gz
./<name>/<name>
```

If the bundle has an `assets/` folder, keep it next to the binary.

Requirements:

* x86_64 GNU/Linux with glibc 2.39 or newer (e.g. Debian 13, Ubuntu 24.04, Fedora 40)
* libasound, libudev and libwayland-client. On Debian/Ubuntu: `libasound2t64 libudev1 libwayland-client0`
* X11 (libX11, libXcursor, libXi, libXrandr, libxkbcommon-x11) or Wayland (libxkbcommon) session
* Vulkan driver (libvulkan1 + Mesa/vendor driver)

### Windows

Extract `<name>-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `<name>\<name>.exe`. If the bundle has an `assets\` folder, keep it next to the executable.

Requirements:

* Windows 10 or 11, x64
* GPU with Direct3D 12 or Vulkan driver

The executable (and the self-extracting `.exe`) is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.
