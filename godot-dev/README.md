# godot-dev

Dockerized development environment for [Godot](https://godotengine.org) 4.7 with C# (.NET 10).

## > Usage

```
./project.sh start              # build the image, generate the Hello project, build and run it
./project.sh bundleforlinux     # dist/Hello-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/Hello-windows-x86_64.zip
./project.sh bundleformac       # dist/Hello-macos.zip
./project.sh clean
```

Run `./project.sh start` once before bundling. Bundles are exported with the official Godot export templates, which are installed in the image. On the first bundle `exportsetup` creates `export_presets.cfg` and `Hello.sln`. It also enables two settings exports need: ETC2/ASTC texture import in `project.godot` (required for macOS) and `InvariantGlobalization` in `Hello.csproj` (so the Linux build does not depend on the system libicu).

Each bundle contains a self-contained .NET runtime (`data_Hello_*` folder), so .NET does not need to be installed on the target machine.

## > Running the bundles

### Linux

```
tar -xzf Hello-linux-x86_64.tar.gz
./Hello/Hello.x86_64
```

Keep `data_Hello_linuxbsd_x86_64` next to `Hello.x86_64`.

Requirements:

* x86_64 GNU/Linux with glibc 2.28 or newer (any distro supported by .NET 10, e.g. Debian 13, Ubuntu 22.04, Fedora 43, RHEL 8)
* X11 (libX11, libXcursor, libXext, libXi, libXinerama, libXrandr, libXrender, libxkbcommon) or Wayland (libwayland-client, libwayland-cursor, libwayland-egl, libdecor) session
* Vulkan driver (libvulkan1 + Mesa/vendor driver). Without Vulkan, Godot falls back to OpenGL 3.3 (libGL/libEGL).
* optional: libpulse or libasound for audio, libfontconfig for system fonts, libdbus, libudev for gamepads

### Windows

Extract `Hello-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `Hello\Hello.exe`. Keep `data_Hello_windows_x86_64` next to `Hello.exe`.

Requirements:

* Windows 10 or 11, x64
* GPU with Vulkan or Direct3D 12 driver. Without them, Godot falls back to OpenGL 3.3.

The executable is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.

### macOS

Double-click `Hello-macos.zip` in Finder and start `Hello.app`. It is a universal app (Apple Silicon and Intel).

Requirements:

* macOS 15 or newer. That is the oldest version .NET 10 supports; Godot itself needs macOS 11 on Intel and 13 on Apple Silicon.

The app is only ad-hoc signed and not notarized, so macOS blocks the first start. Allow it in *System Settings* → *Privacy & Security* → *Open Anyway*, or remove the quarantine flag:

```
xattr -dr com.apple.quarantine Hello.app
```
