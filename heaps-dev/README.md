# heaps-dev

Dockerized development environment for [Heaps](https://heaps.io) games running on [HashLink](https://hashlink.haxe.org).

## > Usage

```
./project.sh start              # build the image, install haxelibs, compile and run src/Main.hx
./project.sh bundleforlinux     # dist/Hello-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/Hello-windows-x86_64.zip
./project.sh bundleformac       # dist/Hello-macos.zip
./project.sh clean
```

Run `./project.sh start` once before bundling. Each bundle recompiles `hello.hl` and packs it together with the HashLink runtime as `hlboot.dat`. If a `res/` directory exists, it is copied into the bundle.

## > Running the bundles

### Linux

```
tar -xzf Hello-linux-x86_64.tar.gz
./Hello/Hello
```

The `Hello` launcher script starts the bundled `hl` with the bundled libraries (SDL3, OpenAL, libpng, libvorbis, mbedtls, libuv, ...). It can be started from any directory.

Requirements:

* x86_64 GNU/Linux with glibc 2.38 or newer (e.g. Debian 13, Ubuntu 24.04, Fedora 39)
* OpenGL driver (Mesa or vendor driver) and X11 or Wayland session
* libraries every desktop provides and that are therefore not bundled:
  libstdc++, libgcc_s, libX11, libXcursor, libXext, libXfixes, libXi, libXrandr, libXss, libxkbcommon, libdrm, libgbm, libasound, libpulse and libpipewire.
  On Debian/Ubuntu: `libstdc++6 libx11-6 libxcursor1 libxext6 libxfixes3 libxi6 libxrandr2 libxss1 libxkbcommon0 libdrm2 libgbm1 libasound2t64 libpulse0 libpipewire-0.3-0t64 libgl1 libgl1-mesa-dri`

### Windows

Extract `Hello-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `Hello\Hello.exe`. Keep all files in the folder together: `Hello.exe` is HashLink's `hl.exe`, which loads `hlboot.dat` and the `.hdll`/`.dll` files next to it.

The bundle uses HashLink's MinGW build instead of the MSVC one, so it does not need the Microsoft Visual C++ Redistributable. Its runtime DLLs are bundled: `libstdc++-6.dll`, `libgcc_s_seh-1.dll` and `libwinpthread-1.dll` from Debian's MinGW-w64 packages, and `SDL3.dll` from HashLink's MSVC release, which has no Visual C++ runtime dependency. Everything else it imports is part of Windows.

Requirements:

* Windows 10 or 11, x64. Older versions also need the Universal C Runtime, which is built into Windows 10 and later.
* OpenGL capable GPU driver

The executable is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.

### macOS

Double-click `Hello-macos.zip` in Finder and start `Hello.app`.

Requirements:

* macOS 11 or newer
* on Apple Silicon: [Rosetta 2](https://support.apple.com/en-us/102527). HashLink's JIT exists only for x86_64, so the app runs translated (macOS offers to install Rosetta on first start). Apple has announced that general Rosetta support ends after macOS 27.

The app is neither signed nor notarized, so macOS blocks the first start. Allow it in *System Settings* → *Privacy & Security* → *Open Anyway*, or remove the quarantine flag:

```
xattr -dr com.apple.quarantine Hello.app
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
