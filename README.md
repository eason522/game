# Tian Yuan Mi Ju

Godot 4.x prototype for **Tian Yuan Mi Ju**, a roguelike strategy game built from a gomoku core.

## Current Stage

Phase 1 is started:

- 11x11 board
- player and simple AI alternating turns
- legal piece placement
- five-in-a-row win detection
- clearer turn, move count, last move, and winning line feedback
- basic rule smoke tests for horizontal, vertical, and diagonal wins

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
