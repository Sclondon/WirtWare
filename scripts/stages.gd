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


static func theme(stage: int) -> Dictionary:
	return THEMES[posmod(stage, THEMES.size())]
