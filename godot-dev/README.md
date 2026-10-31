# godot-dev

Dockerized development environment for [Godot](https://godotengine.org) 4.7 with C# (.NET 10).

## > Usage

```
./project.sh start              # build the image, generate the project, build and run it
./project.sh bundleforlinux     # dist/<name>-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/<name>-windows-x86_64.zip
./project.sh bundleformac       # dist/<name>-macos.zip
./project.sh makebundles        # dist/<name>-linux-x86_64.sh, dist/<name>-windows-x86_64.exe and dist/<name>-macos.dmg from the bundles above
./project.sh clean
```

`<name>` stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `godot-dev`. It names the Godot project (`config/name`), the C# project and assembly, the exported executables, the bundles and the window title. Use lowercase letters, digits and dashes, as the name is used in file names.

Run `./project.sh start` once before bundling. Bundles are exported with the official Godot export templates, which are installed in the image. On the first bundle `exportsetup` creates `export_presets.cfg` and `<name>.sln`. It also enables two settings exports need: ETC2/ASTC texture import in `project.godot` (required for macOS) and `InvariantGlobalization` in `<name>.csproj` (so the Linux build does not depend on the system libicu).

Each bundle contains a self-contained .NET runtime (`data_<name>_*` folder), so .NET does not need to be installed on the target machine.

The generated project:

* `project.godot` - the project settings. The viewport is 960x540 and scaled to fit the window (`canvas_items` stretch mode), so the layout does not depend on the window size.
* `<name>.csproj` - the C# project
* `main.tscn` and `Main.cs` - the main scene, which adds the `Hello` node
* `Hello.cs` - a label with the greeting in the middle of the viewport. Add further parts of the game as nodes or scenes of their own.

## > GPU

`docker-compose.yml` is generated on the first run and passes the host's GPU to the container if one exists:

* Intel and AMD (Mesa): `/dev/dri` is mapped into the container. On laptops with an additional AMD GPU, `DRI_PRIME` selects it.
* NVIDIA (proprietary driver): requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. The GPU is reserved for the container and selected for OpenGL and Vulkan, also on laptops with PRIME render offload. Without the toolkit, `project.sh` prints a warning and the container falls back to the other GPU or to software rendering.

The file is not regenerated, so delete `docker-compose.yml` after adding or removing a GPU or installing the toolkit.

## > Self-extracting bundles

`./project.sh makebundles` packs the bundles made by `bundleforlinux`, `bundleforwindows` and `bundleformac` (whichever exist) into single files:

* `dist/<name>-linux-x86_64.sh` is a shell script with the bundle appended as a tar.gz. It unpacks the bundle into a temporary directory, runs it and removes the directory when the game exits: `sh <name>-linux-x86_64.sh` (or `chmod +x` it and start it directly).
* `dist/<name>-windows-x86_64.exe` is a silent NSIS installer doing the same in the user's temporary directory. It needs no administrator rights.
* `dist/<name>-macos.dmg` is a disk image with the app from `<name>-macos.zip` and a link to `Applications`, the usual way to install a Mac app: open it and drag the app onto `Applications`. The image is not compressed, so it is larger than the zip.

The requirements are the same as for the bundles below, and the files are not signed either (see there). Godot keeps saved data in `user://`, which is in the user's data directory, so it persists although the game runs from a temporary directory.

## > Running the bundles

### Linux

```
tar -xzf <name>-linux-x86_64.tar.gz
./<name>/<name>.x86_64
```

Keep `data_<name>_linuxbsd_x86_64` next to `<name>.x86_64`.

Requirements:

* x86_64 GNU/Linux with glibc 2.28 or newer (any distro supported by .NET 10, e.g. Debian 13, Ubuntu 22.04, Fedora 43, RHEL 8)
* X11 (libX11, libXcursor, libXext, libXi, libXinerama, libXrandr, libXrender, libxkbcommon) or Wayland (libwayland-client, libwayland-cursor, libwayland-egl, libdecor) session
* Vulkan driver (libvulkan1 + Mesa/vendor driver). Without Vulkan, Godot falls back to OpenGL 3.3 (libGL/libEGL).
* optional: libpulse or libasound for audio, libfontconfig for system fonts, libdbus, libudev for gamepads

### Windows

Extract `<name>-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `<name>\<name>.exe`. Keep `data_<name>_windows_x86_64` next to `<name>.exe`.

Requirements:

* Windows 10 or 11, x64
* GPU with Vulkan or Direct3D 12 driver. Without them, Godot falls back to OpenGL 3.3.

The executable is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.

### macOS

Double-click `<name>-macos.zip` in Finder and start `<name>.app`. It is a universal app (Apple Silicon and Intel).

Requirements:

* macOS 15 or newer. That is the oldest version .NET 10 supports; Godot itself needs macOS 11 on Intel and 13 on Apple Silicon.

The app is only ad-hoc signed and not notarized, so macOS blocks the first start. Allow it in *System Settings* → *Privacy & Security* → *Open Anyway*, or remove the quarantine flag:

```
xattr -dr com.apple.quarantine <name>.app
```
