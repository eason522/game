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
- Rock King battles now show first-five-turn observation hints inside the battle tutorial panel so live playtests can track opening rock pressure before recording route-side feel
- Rock King battles now pass first-five-turn observation snapshots back to the run map, where the feel panel and build summary show key opening moves, energy, rock pressure, and counterplay focus
- run map now interprets Rock King first-five-turn snapshots into a pressure readout, summarizing rock count, playable-space loss, player energy, and the next review focus
- live tuning verdicts and closeout now treat high-pressure Rock King snapshots as a Boss-only review signal even when the full-run turn count is on target
- run map now includes a rest-focus feel audit that cross-checks rest-focus activation, Boss snapshots, and first-five-turn feel before closing Boss tuning
- run map now includes an editor acceptance line that combines the full-run sample, Boss snapshot pressure, rest-focus status, and first-five-turn feel into a final live-playtest gate
- run map now includes an editor next-action guide that points to the immediate live-playtest action: enter a node, claim loot, resolve a route choice, record Boss feel, or stop after acceptance
- run map now includes an editor evidence checklist that summarizes sample coverage, target ratio, total turns, Boss snapshot pressure, rest-focus status, first-five-turn feel, and whether the run can be archived as demo acceptance evidence
- run map now includes an editor acceptance note that condenses the current run into a recordable result: incomplete sample, Boss-only review, missing Boss feel, or demo acceptance
- run map now includes an editor archive record line that says whether the current live run should be archived as demo acceptance, Boss-only review, a failed-run review, or a still-open sample
- run map now includes an editor recap excerpt that condenses the current live run into a copyable one-line playtest note
- run map now includes an editor closeout packet that pairs the live-run verdict with the exact next action: archive, record Boss feel, run Boss-only review, or keep the sample open
- battle screen presentation now has a layered stage background, framed board tray, jade/ink piece symbols, polished side-panel headers, and selected skill-button styling instead of the earlier debug-like flat UI
- board cells now use a custom pseudo-3D renderer for faceted rocks, jade-piece highlights, dark enemy stones, spirit cores, warning marks, and feedback outlines instead of relying on text glyphs
- the battle board now uses a continuous single-board material pass: zero per-cell gaps, no per-cell button shadows, subtle wood-grain variation, low-contrast grid lines, thicker jade/ink stones, and stronger rock/spirit tokens
- the battle board now uses generated bitmap art at `assets/board/battle_board_frame_v1.png` for the carved wood frame and aged gold play surface, with Godot drawing only the exact grid and transparent click layer on top
- demo now starts from a main menu with continue, new-run, and single-battle entry points
- main menu now previews the saved Run's editor next action and closeout packet before continuing a live playtest
- main menu continue button now names the immediate saved-run action, such as entering the current node, claiming loot, recording Boss feel, or reviewing acceptance
- main menu now shows a saved-run progress line with the current node, recorded battle count, and on-target progress before entering the run map
- main menu now includes a one-line live-run launch check that combines the continue action, saved-run progress, and closeout packet before entering the run map
- main menu now shows the automatic baseline playtest's on-target battle count, total turns, starsand, and reward count before a live run starts
- main menu now surfaces the first live playtest checklist action so saved runs show whether to start the first battle or continue filling the full-run sample
- main menu now surfaces the first Boss live-check focus so runs call out rest-focus, pre-Boss resources, or Boss opening review before entering the map
- main menu now surfaces the Boss opening snapshot pressure readout so saved runs reveal missing, stable, or high-pressure first-five-turn evidence before entering the map
- main menu now surfaces the editor evidence checklist so sample coverage, Boss snapshot pressure, rest-focus status, and feel notes are visible before entering the map
- main menu now surfaces the editor acceptance gate so saved runs show whether the live sample is incomplete, missing Boss feel, Boss-only, or ready for demo acceptance
- main menu now surfaces the editor acceptance note so saved runs have a recordable live-playtest result before entering the map
- main menu now surfaces the editor archive result and recap excerpt so accepted, partial, or Boss-only saved runs can be classified before entering the map
- main menu now surfaces the live run closeout result and its next action so saved runs show whether to keep sampling, record Boss feel, run Boss-only review, or preserve current values before entering the map
- main menu and the run map now show a Demo acceptance packet that combines current status, next action, evidence, Boss risk, and archive wording into one live-playtest closeout view
- main menu and the run map now show a stable Demo acceptance rehearsal sample so editor playtests have a concrete accepted-run target before a real manual run
- accepted Demo rehearsal samples now save a Demo archive record with the pass result, target ratio, total turns, Boss evidence, and next action, then restore that record through the run save
- stable completed Demo runs now save the Demo archive record when the Boss feel button closes the evidence loop
- main menu and the run map now show a Demo archive review packet that distinguishes saved archives, still-open samples, and the exact next review action
- Demo archive records now include a deterministic review signature plus a closed-evidence summary, and the main menu and run map show the archive audit before a real editor acceptance rerun
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
- battle feedback smoke tests for action logs, cell flashes, result banners, generated board texture loading, polished board frame, refined legend copy, zero-gap continuous board material, no per-tile button shadows, and pseudo-3D rock visual state
- main menu smoke tests for default project entry, save-aware continue state, demo entry buttons, saved-run progress, saved-run closeout overview, state-aware continue action labels, the live-run launch check, the baseline playtest line, the live checklist action, the Boss focus line, the Boss snapshot line, the evidence line, the acceptance gate line, the acceptance note line, the archive/recap line, the closeout line, the Demo acceptance packet, the Demo archive review packet, and the archive audit signature
- run map feedback smoke tests for typed settlement labels, tone triggers, live playtest checklist/verdict/review/Boss validation display, Boss snapshot pressure assessment, rest-focus feel audit, editor acceptance gates, editor next-action/evidence/note/archive/recap/closeout-packet guidance, Demo acceptance packet states, Demo archive review/audit states, priority verdicts, Boss feel recording, and tuning candidate display
- demo acceptance flow smoke tests for the stable rehearsal sample, save restore, main-menu review state, run-map acceptance packet, Boss feel/archive preservation, archive review/audit display, archive signature preservation, and archive next action

## Run Locally

1. Install Godot 4.x.
2. Open this repository folder in Godot.
3. Press Play to start at `scenes/ui/MainMenu.tscn`. The menu can continue a saved Run with a state-aware action label, preview saved-run progress plus its editor next action and closeout packet, show a one-line live-run launch check, automatic baseline playtest summary, stable Demo acceptance rehearsal, first live checklist action, Boss focus line, Boss snapshot line, evidence line, acceptance gate line, acceptance note line, archive/recap line, closeout line, Demo acceptance packet, Demo archive review packet, archive audit signature, and saved Demo archive record, start a new Run, or open `scenes/game/BattleScene.tscn` for a single battle.

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
godot --headless --path . --script tests/main_menu_smoke.gd
godot --headless --path . --script tests/run_map_feedback_smoke.gd
godot --headless --path . --script tests/demo_acceptance_flow_smoke.gd
```
