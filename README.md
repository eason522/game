# Tian Yuan Mi Ju

Godot 4.x prototype for **Tian Yuan Mi Ju**, a roguelike strategy game built from a gomoku core.

## Current Stage

Phase 2 terrain basics are playable:

- 11x11 board
- player and simple AI alternating turns
- legal piece placement
- five-in-a-row win detection
- clearer turn, move count, last move, and winning line feedback
- visible spirit and rock terrain cells
- spirit cells grant energy when occupied
- rock cells block placement and five-in-a-row lines
- AI avoids rocks and has a scoring preference for spirit cells
- basic rule smoke tests for horizontal, vertical, and diagonal wins
- terrain smoke tests for rock blocking and AI spirit-cell priority

## Run Locally

1. Install Godot 4.x.
2. Open this repository folder in Godot.
3. Run `scenes/game/BattleScene.tscn` or press Play.

On this machine Godot 4.7 is installed through WinGet. `godot` and `godot4` command shims are available from `C:\Users\eason\bin`.

```powershell
godot4 --version
```

## Smoke Tests

Run:

```powershell
godot --headless --path . --script tests/rule_checker_smoke.gd
```
