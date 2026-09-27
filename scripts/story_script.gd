extends RefCounted
## ── WRITE YOUR STORY HERE ──────────────────────────────────────────────
## This is the only file Story Mode reads for dialogue. Nothing outside
## this file needs to change to rewrite the story — see story_director.gd
## / story_dialogue.gd only if you want to change how it's presented.
##
## Story Mode runs the same matchup order as Arcade (every roster fighter
## once, in the order they're beaten, always ending with Anant) and fires
## these beats around each fight:
##   PROLOGUE          → once, before the very first fight.
##   CHAPTERS[id].intro    → before you fight that opponent.
##   CHAPTERS[id].victory  → right after you beat them.
##   CHAPTERS[id].defeat   → if they beat you (you then retry the same fight).
##   FINALE             → once, after Anant falls.
##
## Each block is an Array of lines, shown one at a time (advance with
## Enter/Space/click, or Esc to skip the whole block):
##   {"speaker": "ish", "text": "Keep up if you can."}
## "speaker" is a fighter id from fighter_roster.gd's PROFILES ("anug",
## "ish", "sab", "bib", "abhi", "sup", "anant"), "player" for whichever
## fighter the player chose, or "" for narration. An empty array ([]) skips
## that beat entirely — e.g. leave CHAPTERS[id].defeat as [] if you don't
## want a loss line for that fighter.
##
## The cutscene camera picks its own shot (a close-up on whoever speaks,
## wide shots and two-shots for narration). Add a "shot" key to choose one:
## "wide", "two", "hero", "close_player" or "close_rival".
##
## Dubbing a line is optional and opt-in per line — add a "voice" key with
## the clip's res:// path (.ogg/.wav/.mp3, imported like any other Godot
## audio asset) and story_dialogue.gd plays it the instant that line shows:
##   {"speaker": "ish", "text": "Keep up if you can.", "voice": "res://audio/voice/ish_intro_01.ogg"}
## Lines with no "voice" key (every line right now) just stay silent — text
## alone is never blocked on a clip existing, so you can dub incrementally,
## one character or one chapter at a time, and leave the rest untouched.

const PROLOGUE := [
	{"speaker": "", "text": "Kathmandu. Old stone, older rivalries."},
	{"speaker": "", "text": "Seven fighters. One title. Every square in the valley has a name to settle."},
	{"speaker": "player", "text": "Then I'll settle all of them."},
	{"speaker": "", "text": "The road to the top starts now.", "shot": "hero"},
]

const CHAPTERS := {
	"anug": {
		"intro": [
			{"speaker": "", "text": "Anug has never let anything past him. Not a ball. Not a punch."},
			{"speaker": "anug", "text": "Nothing gets past me. Not today."},
			{"speaker": "player", "text": "Then stand still and try to stop this."},
		],
		"victory": [
			{"speaker": "anug", "text": "...Huh. Didn't see that one coming."},
			{"speaker": "player", "text": "Nobody ever does."},
		],
		"defeat": [
			{"speaker": "anug", "text": "Saved. Come back when you've got a real shot."},
		],
	},
	"ish": {
		"intro": [
			{"speaker": "", "text": "Ish hits first and asks questions never."},
			{"speaker": "ish", "text": "Blink and it's over."},
			{"speaker": "player", "text": "Then I won't blink."},
		],
		"victory": [
			{"speaker": "ish", "text": "Okay. Okay! That one counts, I guess."},
		],
		"defeat": [
			{"speaker": "ish", "text": "Too slow. Told you."},
		],
	},
	"sab": {
		"intro": [
			{"speaker": "", "text": "They call Ballas the Iron Grip. Nobody has ever pulled free."},
			{"speaker": "sab", "text": "Once I've got you, you're not leaving."},
			{"speaker": "player", "text": "You have to catch me first."},
		],
		"victory": [
			{"speaker": "sab", "text": "Strong grip. Stronger will. Respect."},
		],
		"defeat": [
			{"speaker": "sab", "text": "Told you. Nobody leaves."},
		],
	},
	"bib": {
		"intro": [
			{"speaker": "", "text": "Bib never runs out of breath. His rivals always do."},
			{"speaker": "bib", "text": "Catch me if you can!"},
			{"speaker": "player", "text": "I don't need to catch you. Just once."},
		],
		"victory": [
			{"speaker": "bib", "text": "Guess I ran out of road."},
		],
		"defeat": [
			{"speaker": "bib", "text": "Still fresh. You?"},
		],
	},
	"abhi": {
		"intro": [
			{"speaker": "", "text": "Abhi fights loud. The crowd loves it. His rivals hate it."},
			{"speaker": "abhi", "text": "Let me tell you exactly how this ends."},
			{"speaker": "player", "text": "Less talking."},
		],
		"victory": [
			{"speaker": "abhi", "text": "...I was talking. That's not fair."},
		],
		"defeat": [
			{"speaker": "abhi", "text": "See? Exactly how I said."},
		],
	},
	"sup": {
		"intro": [
			{"speaker": "", "text": "Supreme moves like the wind through prayer flags. Never where you aim."},
			{"speaker": "sup", "text": "Catch the wind if you can."},
			{"speaker": "player", "text": "Wind stops eventually."},
		],
		"victory": [
			{"speaker": "sup", "text": "The spiral breaks. Well fought."},
			{"speaker": "sup", "text": "He's waiting at the stupa. He's been waiting for you."},
		],
		"defeat": [
			{"speaker": "sup", "text": "Too straight. Flow, or fall."},
		],
	},
	"anant": {
		"intro": [
			{"speaker": "", "text": "Night at the stupa. The flags go quiet."},
			{"speaker": "anant", "text": "Everyone who reached me thought they were ready."},
			{"speaker": "player", "text": "I'm not everyone."},
			{"speaker": "anant", "text": "We'll see."},
		],
		"victory": [
			{"speaker": "anant", "text": "...The final word belongs to you, then."},
		],
		"defeat": [
			{"speaker": "anant", "text": "Not yet. Come back when you mean it."},
		],
	},
}

const FINALE := [
	{"speaker": "", "text": "Seven names on the board. Now there's only one."},
	{"speaker": "player", "text": "Tell the valley. The title stays here."},
	{"speaker": "", "text": "THE END.", "shot": "wide"},
]
