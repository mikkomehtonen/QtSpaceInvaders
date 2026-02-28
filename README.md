# Qt Space Invaders

A classic Space Invaders style game built with Qt 6 and QML.

## Features

- Traditional Space Invaders gameplay loop
- Wave progression with increasing difficulty
- Player lives, score, and persistent high score
- Pause/resume support
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

## Run

```bash
./build/appQtSpaceInvaders
```

## Controls

- `Enter`: Start game / next wave / restart after game over
- `A` / `Left Arrow`: Move left
- `D` / `Right Arrow`: Move right
- `Space`: Fire
- `P`: Pause / resume
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
