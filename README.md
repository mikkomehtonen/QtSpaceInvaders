# Qt Space Invaders

A classic Space Invaders style game built with Qt 6 and QML.

## Features

- Traditional Space Invaders gameplay loop
- Wave progression with increasing difficulty
- Player lives, score, and persistent high score
- Bomb weapon system with score-based recharge (every 1000 points, max 3)
- Short player hit/death animation on impact
- Pause/resume support
- Toggleable in-game help screen with full control list
- Sound effects for key game events
- Sci-fi background music playlist with keyboard controls
- Retro-styled QML `Canvas` rendering

## Requirements

- Qt 6.8+ with modules:
  - `Qt Quick`
  - `Qt Multimedia`
- CMake 3.16+
- A C++ compiler (GCC/Clang/MSVC)

## Build

```bash
cmake -S . -B build
cmake --build build
```

## Flatpak Bundle

Build and install locally:

```bash
flatpak-builder --disable-rofiles-fuse --user --install --force-clean build-release com.mehtonen.QtSpaceInvaders.json
```

Create a distributable bundle:

```bash
flatpak build-bundle ~/.local/share/flatpak/repo QtSpaceInvaders.flatpak com.mehtonen.QtSpaceInvaders
```

## Run

```bash
./build/appQtSpaceInvaders
```

## Controls

- `Enter`: Start game / next wave / restart after game over
- `A` / `Left Arrow`: Move left
- `D` / `Right Arrow`: Move right
- `Space`: Fire
- `B`: Launch bomb (earns every 1000 points, max 3)
- `P`: Pause / resume
- `H`: Toggle help screen
- `M`: Mute / unmute music
- `-`: Music volume down
- `=` (or `+`): Music volume up

## High Score

High score is stored locally using `QtQuick.LocalStorage` (SQLite-backed) and survives app restarts.

## Project Layout

- `main.cpp`: Qt app entry point and QML engine bootstrap
- `Main.qml`: Game logic, rendering, input, audio, persistence
- `assets/sfx/`: Sound effects
- `assets/music/`: Background music tracks
- `CMakeLists.txt`: Build and QML resource configuration
