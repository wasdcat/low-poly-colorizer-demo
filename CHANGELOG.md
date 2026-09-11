# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-11

### Changed
- **Scramble to Play**: The button is filled with the accent color, so it stands out as the panel's main action.
- **One Game at a Time**: *Scramble to Play* is locked while a game is on. Solving the cube or clicking *Reset* unlocks it again. Changing the cube's size also ends the game and unlocks it. *Reset* can only be clicked during a game.
- **Builds**: Only the latest release keeps the Windows, Linux and macOS builds. Publishing a new release removes them from the older ones, which keep their notes and source code.

## [1.0.0] - 2026-09-11

### Added
- **Puzzle Cube**: Any size from 2×2×2 to 7×7×7, built at runtime from just two meshes (body and sticker), with adjustable gaps between the cubies. Every turn is an animated rotation of a real layer.
- **Mouse Controls**: The sticker under the cursor picks the layer, middle slices included. The wheel turns its column, Shift + wheel its row and Alt + wheel its face, and a white outline marks the layer that turns next. Drag to orbit the view, Ctrl + wheel to zoom, Ctrl + Z to undo.
- **Game Mode**: *Scramble to Play* mixes the cube up and counts your moves until it is solved. *Undo* and *Reset* are available at any time.
- **LPC Looks**: All bodies and stickers share the `lpc_singlecolor` material from Low Poly Colorizer's Godot export. Each node gets its own look through instance uniforms. The demo offers six sticker schemes (Classic, Showroom, Neon, Rainbow, Shades, Greyscale), a random scheme, and four body looks (Black, White, Steel, Gold). All of them are small `.tres` resources, and every LPC call lives in `scripts/cube_looks.gd`.
- **Showroom Scene**: A starfield sky backdrop. Reflections and ambient light come from a soft studio room, so the Metallic and Clearcoat presets stay readable. When left alone, the camera slowly circles the cube.
- **Interface**: A side panel with the puzzle and look settings, a move counter, and *Help* and *About* windows. The UI is available in English and German, starts in the system language and can be switched with the flag buttons.
- **Builds**: Export presets for Windows, Linux, macOS and Web. GitHub Actions attaches the Windows, Linux and macOS builds to every published release.
- **Tests**: A headless test suite covering the puzzle logic, the looks and the translations. GitHub Actions runs it on every push.
