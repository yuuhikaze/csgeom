---
title: Computational Geometry Algorithms
---

Implementation of computational geometry algorithms with real-time visualization using SDL3.

# Getting Started

This project uses Nix for reproducible builds and Zig as the implementation language.

## Prerequisites

Have Nix package manager installed.

1.  Follow installation instructions from official Nix wiki: <https://nix.dev/install-nix.html>

    > Supported platforms: Linux, MacOS, WSL2, Docker

1.  Enable `nix-command` and `flakes` features. Edit `/etc/nix/nix.conf` and add the following line.

    ```conf
    experimental-features = nix-command flakes
    ```

## Setting Up the Environment

Enter the development shell to get access to Zig and SDL3:

```bash
nix develop
```

This provides the correct Zig compiler version and SDL3 library automatically.

## Building the Project

Once in the development environment, compile the project:

```bash
zig build
```

The compiled binary will be placed in `zig-out/bin/`.

## Running

Navigate to the output directory:

```bash
cd zig-out/bin
```

Run the program with default settings:

```bash
./csgeom
```

To see available options and algorithms:

```bash
./csgeom --help
```
