extends RefCounted

## Only the user's requested MAX COMBO cue remains active during this audition.
## The other candidate effects stay disabled until the user selects replacements.
const MENU_SELECT = null
const SONG_SELECT = null
const CONFIRM = null
const RESUME = null
const PAUSE = null
const LOADING = null
const PERFECT_COMBO := preload("res://assets/audio/djmax_trial/max_combo_original.mp3")
const STAGE_CLEAR = null
const SCORE_COUNT = null
const SCORE_FINISH = null
const COUNTDOWN = {
	3: null,
	2: null,
	1: null,
	0: null,
}