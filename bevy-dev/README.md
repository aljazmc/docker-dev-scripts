# bevy-dev

Dockerized development environment for the [Bevy](https://bevy.org) game engine.

## > Usage

```
./project.sh start              # build the image, generate the hello crate, build and run it
./project.sh bundleforlinux     # dist/Hello-linux-x86_64.tar.gz
./project.sh bundleforwindows   # dist/Hello-windows-x86_64.zip
./project.sh clean
```

`./project.sh start` generates a `hello` crate (`Cargo.toml` and `src/main.rs`) that depends on bevy from crates.io and shows "Hello Bevy!" in a window. Existing files are not overwritten, so you can develop your own game in their place. Run `./project.sh start` once before bundling.

Each bundle contains the stripped release binary, renamed to `Hello` (`Hello.exe` on Windows), and the project's `assets/` folder if it exists. The Windows binary is cross-compiled with MinGW (`x86_64-pc-windows-gnu`) and linked statically, so it does not need any MinGW or Visual C++ runtime DLLs.

There is no `bundleformac`: cross-compiling for macOS requires Apple's macOS SDK, which may only be used on Apple hardware.

## > Running the bundles

### Linux

```
tar -xzf Hello-linux-x86_64.tar.gz
./Hello/Hello
```

If the bundle has an `assets/` folder, keep it next to the binary.

Requirements:

* x86_64 GNU/Linux with glibc 2.39 or newer (e.g. Debian 13, Ubuntu 24.04, Fedora 40)
* libasound, libudev and libwayland-client. On Debian/Ubuntu: `libasound2t64 libudev1 libwayland-client0`
* X11 (libX11, libXcursor, libXi, libXrandr, libxkbcommon-x11) or Wayland (libxkbcommon) session
* Vulkan driver (libvulkan1 + Mesa/vendor driver)

### Windows

Extract `Hello-windows-x86_64.zip` (Explorer: *Extract All*) and double-click `Hello\Hello.exe`. If the bundle has an `assets\` folder, keep it next to the executable.

Requirements:

* Windows 10 or 11, x64
* GPU with Direct3D 12 or Vulkan driver

The executable is not signed, so SmartScreen may ask for confirmation: *More info* → *Run anyway*.
