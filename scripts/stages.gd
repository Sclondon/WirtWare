class_name Stages
extends RefCounted
## The three stages of a run. Each borrows its look from another game in the
## Scareathon arcade, and ends in a boss. Microgames read [member Microgame.stage]
## and THEMES[stage] to dress themselves for the stage they appear in.

const GRAVEYARD := 0
const TEMPLE := 1
const SWAMP := 2

const THEMES: Array[Dictionary] = [
	{
		"name": "GRAVEYARD SHIFT",
		"from": "8 Bit Evil Returns",
		"art": "graveyard",
		"boss": "res://bosses/mr_hat/mr_hat.tscn",
		"boss_name": "MR HAT",
		"boss_sprite": ["graveyard/mr_hat", 5],
		"sky": Color("2a1f4a"), "sky_low": Color("5b3a73"),
		"ground": Color("3b2f4f"), "accent": Color("ff9a3c"), "glow": Color("ffe8a3"),
		"curtains": [Color("ff7a1a"), Color("7b5cff"), Color("3ec16e"), Color("e0457b")],
	},
	{
		"name": "TLALOC'S TEMPLE",
		"from": "Tlaloc's Curse",
		"art": "temple",
		"boss": "res://bosses/tlaloc/tlaloc.tscn",
		"boss_name": "TLALOC",
		"boss_sprite": ["temple/tlaloc", 2],
		"sky": Color("1d4a4f"), "sky_low": Color("3f7f6a"),
		"ground": Color("6b6355"), "accent": Color("f2c14e"), "glow": Color("9ff0c8"),
		"curtains": [Color("2a9d8f"), Color("e9c46a"), Color("e76f51"), Color("3a86ff")],
	},
	{
		"name": "SNAIL LORD'S SWAMP",
		"from": "8 Bit Evil Returns + Hemlock's Tower",
		"art": "swamp",
		"boss": "res://bosses/snail_lord/snail_lord.tscn",
		"boss_name": "SNAIL LORD",
		"boss_sprite": ["swamp/snailLord", 13],
		"sky": Color("10261c"), "sky_low": Color("2e5130"),
		"ground": Color("243d22"), "accent": Color("b6f24e"), "glow": Color("d4ff7a"),
		"curtains": [Color("5a9e3a"), Color("8a5cc7"), Color("2b7a78"), Color("c9a227")],
	},
]


## Fixed looks for the microgames that pay homage to a game that isn't spooky.
## They wear their own game's colours in every stage, never the stage's.
## Same keys as THEMES, so a microgame can use either.
const LOOKS := {
	"salmon_run": {  # Salmon Run 2: a sunny river up through the jungle.
		"sky": Color("5fb4e8"), "sky_low": Color("c9eef0"),
		"ground": Color("6f6a5c"), "accent": Color("ff7a52"), "glow": Color("fff3b0"),
	},
	"wind": {  # Daughter Of The Wind: a bright sky full of clouds.
		"sky": Color("4f9fe8"), "sky_low": Color("dff0ff"),
		"ground": Color("8a7a66"), "accent": Color("d9483b"), "glow": Color("fff8e0"),
	},
	"denver": {  # Denver Vs The Universe: a diorama on a table under hanging lamps.
		"sky": Color("2e2622"), "sky_low": Color("5e4a3a"),
		"ground": Color("8b5a2b"), "accent": Color("ff5a3c"), "glow": Color("ffe2a0"),
	},
	"penguin": {  # Penguin Slide: a snowy slope in daylight.
		"sky": Color("9fd3ff"), "sky_low": Color("dff1ff"),
		"ground": Color("2f6b4f"), "accent": Color("ff4f6d"), "glow": Color("ffcf3a"),
	},
	"band": {  # One Man Band: a red-curtained stage under a spotlight.
		"sky": Color("3a1424"), "sky_low": Color("8a2a36"),
		"ground": Color("6b4428"), "accent": Color("f2c14e"), "glow": Color("fff0c0"),
		"curtains": [Color("c0392b"), Color("f2c14e"), Color("2a9d8f"), Color("3a86ff")],
	},
	"phone_home": {  # Phone Home: a suburb under a big full moon.
		"sky": Color("0d1b3e"), "sky_low": Color("3a5a8c"),
		"ground": Color("2b3a2e"), "accent": Color("ff6b3d"), "glow": Color("fff6d8"),
	},
	"snow_globe": {  # Snow Globe: a winter night, a cottage and pines.
		"sky": Color("1d2b4a"), "sky_low": Color("4a6a9a"),
		"ground": Color("34405e"), "accent": Color("c0392b"), "glow": Color("dff3ff"),
	},
}


static func theme(stage: int) -> Dictionary:
	return THEMES[posmod(stage, THEMES.size())]
