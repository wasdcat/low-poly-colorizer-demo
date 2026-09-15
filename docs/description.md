# Low Poly Colorizer Demo

**A playable, polished puzzle cube in Godot 4 — and a live showcase of the Low Poly Colorizer workflow.**

## About the Game

**Low Poly Colorizer Demo** is a fully playable 3D twisty puzzle cube built in **Godot 4**. Spin, inspect, scramble, and solve cubes from **2×2×2 all the way up to 7×7×7** in a serene, studio-lit space environment.

Featuring an intuitive, angle-independent mouse control scheme, every turn rolls the column, row, or face right under your cursor. An intelligent layer outline tells you what will move before you scroll.

## Why This Demo Exists

Beyond being a satisfying puzzle, this game is a **live technical demonstration** of **[Low Poly Colorizer (LPC)](https://github.com/wasdcat/low-poly-colorizer)** — an open-source Blender extension created by **WASDCAT Games**.

LPC allows 3D artists to paint low-poly models face by face using a single compact palette texture and physically-based material presets (Solid, Metallic, Clearcoat, Emission). With a single click, LPC exports shaders and materials directly into **Godot 4**.

### What this demo proves in a game engine:
- **One Shared Material, Infinite Variety:** Every cubie body and every sticker in the entire game shares **a single material** (`lpc_singlecolor`).
- **Zero Material Duplication, Zero Shader Recompiles:** Colors, roughness, metallic sheen, and glowing emission are driven entirely through **Instance Uniforms** (`set_instance_shader_parameter`). You can switch color schemes or PBR presets at runtime with negligible CPU/GPU cost and minimal draw calls.
- **Built from Just Two Meshes:** The entire puzzle — from 2×2 up to 7×7 — is procedurally assembled from just two meshes (one body, one sticker). No pre-baked cube models required.
- **Cross-Material Consistency:** Because `lpc_singlecolor` shares the exact same palette and presets as LPC’s per-face `lpc_multicolor` shader, all assets in a project can share one unified, harmonious color identity.

## Links & Source

- **Low Poly Colorizer (Blender Extension):** [github.com/wasdcat/low-poly-colorizer](https://github.com/wasdcat/low-poly-colorizer)
- **Source Code (Godot 4 Project):** [github.com/wasdcat/low-poly-colorizer-demo](https://github.com/wasdcat/low-poly-colorizer-demo)
- **WASDCAT Games:** [www.wasdcat.com](https://www.wasdcat.com/)

## Installation & Notes

- **Windows & Linux:** Standalone portable builds. Unzip and run; nothing needs to be installed.
- **macOS:** On its first launch, macOS will block unnotarized apps. To run: go to **System Settings ▸ Privacy & Security** and click **Open Anyway**.

## License

This project is licensed under the [MIT License](LICENSE) — with the exception of the Low Poly Colorizer and WASDCAT Games logos, which remain the property of Frank Winter and are not covered by this license.