# Tian Yuan Mi Ju

Godot 4.x prototype for **Tian Yuan Mi Ju**, a roguelike strategy game built from a gomoku core.

## Current Stage

Phase 5 roguelike outer-loop prototype is playable:

- linear run map from normal battles to the Rock King boss node
- run nodes unlock after victories and lock after defeat
- battle nodes pass the selected enemy profile into the battle scene
- finished route battles can return to the run map and advance progress
- 11x11 board
- player and simple AI alternating turns
- legal piece placement
- five-in-a-row win detection
- clearer turn, move count, last move, and winning line feedback
- visible spirit and rock terrain cells
- spirit cells grant energy when occupied
- rock cells block placement and five-in-a-row lines
- AI avoids rocks and has a scoring preference for spirit cells
- turn-start energy gain with a current max of 6
- skill bar with target highlighting, costs, and tooltips
- six MVP skill prototypes: Po Zhen, Shuang Sheng Zi, Li Yan, Sui Yan, Feng Shou, and Yu Jing
- temporary player pieces that expire and cannot directly complete a five-in-a-row win
- sealed cells that block the enemy's next move and are understood by the AI
- basic rule smoke tests for horizontal, vertical, and diagonal wins
- terrain smoke tests for rock blocking and AI spirit-cell priority
- skill smoke tests for all MVP skill metadata, temporary-piece rules, rock creation/removal, seal behavior, and warning metadata
- roguelike run smoke tests for route shape, progression, defeat, and state roundtrip

## Run Locally

1. Install Godot 4.x.
2. Open this repository folder in Godot.
3. Press Play to start at `scenes/roguelike/RunMapScene.tscn`, or run `scenes/game/BattleScene.tscn` directly for a single battle.

On this machine Godot 4.7 is installed through WinGet. `godot` and `godot4` command shims are available from `C:\Users\eason\bin`.

```powershell
godot4 --version
```

## Smoke Tests

Run:

```powershell
godot --headless --path . --script tests/rule_checker_smoke.gd
godot --headless --path . --script tests/skill_system_smoke.gd
godot --headless --path . --script tests/ai_personality_smoke.gd
godot --headless --path . --script tests/roguelike_run_smoke.gd
```
