# heaps-dev

Dockerized development environment for [Heaps](https://heaps.io) games running on [HashLink](https://hashlink.haxe.org).

## > Usage

```
./project.sh start              # build the image, install haxelibs, compile and run src/Main.hx
./project.sh bundleforlinux     # dist/<name>-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/<name>-windows-x86_64.zip
./project.sh bundleformac       # dist/<name>-macos.zip
./project.sh makebundles        # dist/<name>-linux-x86_64.sh, dist/<name>-windows-x86_64.exe and dist/<name>-macos.dmg from the bundles above
./project.sh clean
```

`<name>` stands for `PROJECT_NAME` in `project.sh`: the name of the directory that contains `project.sh`, e.g. `heaps-dev`. It names the compiled game (`<name>.hl`), the bundles and the window title. Use lowercase letters, digits and dashes, as the name is used in file names.

Run `./project.sh start` once before bundling. Each bundle recompiles `<name>.hl` and packs it together with the HashLink runtime as `hlboot.dat`. If a `res/` directory exists, it is copied into the bundle.

The generated project:

* `compile.hxml` - compiles `src/` to `<name>.hl`
* `src/Main.hx` - sets up the app: window title and size, and adds the `Hello` scene object. The scene always shows a 960x540 area scaled to fit the window (`LetterBox`), so the layout does not depend on the window size.
* `src/Hello.hx` - the greeting in the middle of the scene. Add further parts of the game as classes of their own.
* `res/` - resources for `hxd.Res`, embedded into `<name>.hl` at compile time (`hxd.Res.initEmbed()`)

## > GPU

`docker-compose.yml` is generated on the first run and passes the host's GPU to the container if one exists:

* Intel and AMD (Mesa): `/dev/dri` is mapped into the container. On laptops with an additional AMD GPU, `DRI_PRIME` selects it.
* NVIDIA (proprietary driver): requires the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) on the host. The GPU is reserved for the container and selected for OpenGL and Vulkan, also on laptops with PRIME render offload. Without the toolkit, `project.sh` prints a warning and the container falls back to the other GPU or to software rendering.

The file is not regenerated, so delete `docker-compose.yml` after adding or removing a GPU or installing the toolkit.

## > Self-extracting bundles

`./project.sh makebundles` packs the bundles made by `bundleforlinux`, `bundleforwindows` and `bundleformac` (whichever exist) into single files:

* `dist/<name>-linux-x86_64.sh` is a shell script with the bundle appended as a tar.gz. It unpacks the bundle into a temporary directory, runs it and removes the directory when the game exits: `sh <name>-linux-x86_64.sh` (or `chmod +x` it and start it directly).
* `dist/<name>-windows-x86_64.exe` is a silent NSIS installer doing the same in the user's temporary directory. It needs no administrator rights.
* `dist/<name>-macos.dmg` is a disk image with `<name>.app` and a link to `Applications`, the usual way to install a Mac app: open it and drag the app onto `Applications`.

The requirements are the same as for the bundles below, and the files are not signed either (see there). As the game runs from a temporary directory (and the `.app` possibly from the read-only disk image), write files that should persist, e.g. saved games, to the user's data directory (`~/.local/share/...`, `%APPDATA%\...`, `~/Library/Application Support/...`), not to the working directory, which `hxd.Save` uses by default.

## > Running the bundles

### Linux

```
tar -xzf <name>-linux-x86_64.tar.gz
./<name>/<name>
```

The `<name>` launcher script starts the bundled `hl` with the bundled libraries (SDL3, OpenAL, libpng, libvorbis, mbedtls, libuv, ...). It can be started from any directory.

Requirements:

* x86_64 GNU/Linux with glibc 2.38 or newer (e.g. Debian 13, Ubuntu 24.04, Fedora 39)
* OpenGL driver (Mesa or vendor driver) and X11 or Wayland session
* libraries every desktop provides and that are therefore not bundled:
  libstdc++, libgcc_s, libX11, libXcursor, libXext, libXfixes, libXi, libXrandr, libXss, libxkbcommon, libdrm, libgbm, libasound, libpulse and libpipewire.
  On Debian/Ubuntu: `libstdc++6 libx11-6 libxcursor1 libxext6 libxfixes3 libxi6 libxrandr2 libxss1 libxkbcommon0 libdrm2 libgbm1 libasound2t64 libpulse0 libpipewire-0.3-0t64 libgl1 libgl1-mesa-dri`

### Windows

Extract `<name>-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `<name>\<name>.exe`. Keep all files in the folder together: `<name>.exe` is HashLink's `hl.exe`, which loads `hlboot.dat` and the `.hdll`/`.dll` files next to it.

The bundle uses HashLink's MinGW build instead of the MSVC one, so it does not need the Microsoft Visual C++ Redistributable. Its runtime DLLs are bundled: `libstdc++-6.dll`, `libgcc_s_seh-1.dll` and `libwinpthread-1.dll` from Debian's MinGW-w64 packages, and `SDL3.dll` from HashLink's MSVC release, which has no Visual C++ runtime dependency. Everything else it imports is part of Windows.

Requirements:

* Windows 10 or 11, x64. Older versions also need the Universal C Runtime, which is built into Windows 10 and later.
* OpenGL capable GPU driver

The executable is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.

### macOS

Double-click `<name>-macos.zip` in Finder and start `<name>.app`.

Requirements:

* macOS 11 or newer
* on Apple Silicon: [Rosetta 2](https://support.apple.com/en-us/102527). HashLink's JIT exists only for x86_64, so the app runs translated (macOS offers to install Rosetta on first start). Apple has announced that general Rosetta support ends after macOS 27.

The app is neither signed nor notarized, so macOS blocks the first start. Allow it in *System Settings* → *Privacy & Security* → *Open Anyway*, or remove the quarantine flag:

```
xattr -dr com.apple.quarantine <name>.app
```

## > Licenses

When you distribute a bundle, include the license notices of the bundled third-party libraries. All of them allow redistribution in commercial software:

* HashLink, libuv, libwinpthread, libffi, Wayland client libraries, libdecor: MIT
* SDL3, zlib, libpng: zlib/libpng license
* OpenAL Soft: LGPL-2.1. It stays a separate, replaceable library (`libopenal.so.1`, `OpenAL32.dll`, `libopenal.1.dylib`), which LGPL requires.
* libstdc++, libgcc: GPL-3.0 with the GCC Runtime Library Exception, which allows shipping them with any program
* Mbed TLS: Apache-2.0
* libvorbis, libogg, libjpeg-turbo, libsndio, libbsd, libmd: BSD-style
* SQLite: public domain
