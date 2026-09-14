extends Node
## Tracks which dialogue beat Story Mode is on. Opponent sequencing itself
## stays in match_setup.gd/arena.gd (the same arcade_opponents/arcade_index
## bookkeeping Arcade mode already uses) — this just remembers which of
## story_script.gd's blocks to show and hands them to story_dialogue.gd.
const STORY := preload("res://scripts/story_script.gd")
const ROSTER := preload("res://scripts/fighter_roster.gd")

enum Phase { PROLOGUE, INTRO, VICTORY, DEFEAT, FINALE }
enum Destination { DIALOGUE, ARENA, MENU }

var phase: Phase = Phase.PROLOGUE
var opponent_id: String = ""

func start_run() -> void:
	phase = Phase.PROLOGUE
	opponent_id = ""

## Called once the fight that just ended is fully resolved (win, loss, or
## the run-ending win over Anant) so the right beat plays next.
func report_result(defeated_id: String, won: bool, was_final_boss: bool) -> void:
	opponent_id = defeated_id
	if won and was_final_boss:
		phase = Phase.FINALE
	elif won:
		phase = Phase.VICTORY
	else:
		phase = Phase.DEFEAT

func begin_intro(next_opponent_id: String) -> void:
	opponent_id = next_opponent_id
	phase = Phase.INTRO

func current_lines() -> Array:
	match phase:
		Phase.PROLOGUE:
			return STORY.PROLOGUE
		Phase.FINALE:
			return STORY.FINALE
		Phase.INTRO:
			return STORY.CHAPTERS.get(opponent_id, {}).get("intro", [])
		Phase.VICTORY:
			return STORY.CHAPTERS.get(opponent_id, {}).get("victory", [])
		Phase.DEFEAT:
			return STORY.CHAPTERS.get(opponent_id, {}).get("defeat", [])
	return []

## Skips forward through any beats story_script.gd left empty ([]), landing
## on either a block with real lines to show or a definitive next scene.
## This has to happen BEFORE StoryDialogue is ever entered — resolving an
## empty beat from inside that scene's own _ready() would mean opening it
## only to immediately call change_scene_to_file again from within the
## still-unwinding call stack of the change that opened it, which hangs
## the engine. Pure state advancement here, no scene/node touched.
func resolve() -> Destination:
	var guard := 0
	while current_lines().is_empty() and guard < 20:
		match phase:
			Phase.PROLOGUE, Phase.VICTORY:
				begin_intro(ROSTER.profile(MatchSetup.selected_fighters[1]).id)
			Phase.INTRO, Phase.DEFEAT:
				return Destination.ARENA
			Phase.FINALE:
				return Destination.MENU
		guard += 1
	return Destination.DIALOGUE
