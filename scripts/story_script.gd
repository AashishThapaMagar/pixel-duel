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
## "ish", "sab", "bib", "abhi", "sup", "anant"), or "" for your own line /
## narration. An empty array ([]) skips that beat entirely — e.g. leave
## CHAPTERS[id].defeat as [] if you don't want a loss line for that fighter.

const PROLOGUE := [
	{"speaker": "", "text": "Seven names on the board. One is walking home with the title."},
	{"speaker": "", "text": "Time to find out which one you are."},
]

const CHAPTERS := {
	"anug": {
		"intro": [
			{"speaker": "anug", "text": "Nothing gets past me. Not today."},
		],
		"victory": [
			{"speaker": "anug", "text": "...Huh. Didn't see that one coming."},
		],
		"defeat": [],
	},
	"ish": {
		"intro": [
			{"speaker": "ish", "text": "Blink and it's over."},
		],
		"victory": [
			{"speaker": "ish", "text": "Okay. Okay! That one counts, I guess."},
		],
		"defeat": [],
	},
	"sab": {
		"intro": [
			{"speaker": "sab", "text": "Once I've got you, you're not leaving."},
		],
		"victory": [
			{"speaker": "sab", "text": "Strong grip. Stronger will. Respect."},
		],
		"defeat": [],
	},
	"bib": {
		"intro": [
			{"speaker": "bib", "text": "Catch me if you can!"},
		],
		"victory": [
			{"speaker": "bib", "text": "Guess I ran out of road."},
		],
		"defeat": [],
	},
	"abhi": {
		"intro": [
			{"speaker": "abhi", "text": "Let me tell you exactly how this ends."},
		],
		"victory": [
			{"speaker": "abhi", "text": "...I was talking. That's not fair."},
		],
		"defeat": [],
	},
	"sup": {
		"intro": [
			{"speaker": "sup", "text": "Catch the wind if you can."},
		],
		"victory": [
			{"speaker": "sup", "text": "The spiral breaks. Well fought."},
		],
		"defeat": [],
	},
	"anant": {
		"intro": [
			{"speaker": "anant", "text": "Everyone who reached me thought they were ready."},
			{"speaker": "anant", "text": "Let's see."},
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
	{"speaker": "", "text": "Seven names on the board. Now there's only yours."},
]
