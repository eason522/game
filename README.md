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

The current machine does not have the Godot command line available in PATH, so engine-level validation should be done after opening the project in Godot.

## Smoke Tests

If the Godot command line is available, run:

```powershell
godot --headless --path . --script tests/rule_checker_smoke.gd
```
