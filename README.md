# Tian Yuan Mi Ju

Godot 4.x prototype for **Tian Yuan Mi Ju**, a roguelike strategy game built from a gomoku core.

## Current Stage

Phase 6 tuning has started on top of the playable Phase 5 roguelike loop:

- linear run map from normal battles to the Rock King boss node
- run nodes unlock after victories and lock after defeat
- battle nodes pass the selected enemy profile into the battle scene
- finished route battles can return to the run map and advance progress
- battle victories now offer a three-choice reward before the next node unlocks
- run rewards can raise player energy max, add starting energy, add spirit cells, or refund specific skill use in later battles
- rewards now include rarity labels, stack limits, and exclusive groups for build-defining bonuses
- shops use rarity-based starsand prices, and event rewards distinguish safe gains from higher-risk paid choices
- run map nodes now use clearer visual tiers for battles, events, shops, rests, and the boss
- reward and route choices show build-effect summaries, stack limits, and exclusive-group notes
- run map now keeps a recent settlement note for battle victories, reward claims, route choices, and run completion/failure
- battle endings now show a clear victory/defeat banner, and run settlement notes are typed, color-coded, and preserved through saves
- lightweight generated tones now reinforce battle actions, victory/defeat banners, reward claims, and route settlement feedback
- run map now shows a live full-run playtest checklist and single-axis tuning candidates tied to actual battle records, baseline, and matrix checks
- run map now includes a Boss prep summary and live playtest snapshot for quicker full-run tuning reads
- run map now gates tuning decisions until a complete live run sample exists, then surfaces the priority single-axis candidate
- run map now gives a final live tuning verdict: keep current values, isolate Boss turn tuning, or block tuning until the full sample exists
- run map now shows a live playtest review that summarizes full-run target ratio, Boss pressure, rest-focus validation, and the priority tuning axis
- run map now includes a Boss validation line that compares the live Boss record against target turns, baseline turns, and rest-focus activation
- run map now includes a Boss live checklist for rest-focus verification, pre-Boss resource recording, Boss cap review, and first-five-turn feel checks
- run map now lets completed Boss runs record the first-five-turn feel as stable, pressured, or unclear, and preserves that note in the run save
- live tuning verdicts now treat pressured or unclear first-five-turn Boss feel as a priority signal even when turn counts are on target
- run map now includes a live run closeout line that keeps incomplete samples open, requires Boss first-five-turn feel, and only closes the run when the evidence is ready
- run map now shows a Boss pressure follow-up checklist that focuses the next live sample on rest-focus resources, opening rock pressure, available energy, and first-five-turn counterplay
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
- reward smoke tests for pending reward selection, progression gating, and battle modifier serialization
- tuning smoke tests for reward rarity metadata, stack limits, exclusive groups, and shop pricing
- display smoke tests for reward build summaries, effect descriptions, stack-limit text, and exclusive-group text
- settlement feedback smoke tests for victory, reward-claim, route-choice, and save roundtrips
- battle feedback smoke tests for action logs, cell flashes, and result banners
- run map feedback smoke tests for typed settlement labels, tone triggers, live playtest checklist/verdict/review/Boss validation display, Boss feel recording, and tuning candidate display

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
godot --headless --path . --script tests/battle_feedback_smoke.gd
godot --headless --path . --script tests/run_map_feedback_smoke.gd
```
