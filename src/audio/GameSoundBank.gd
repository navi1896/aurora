extends RefCounted

## Curated UI and gameplay sound bank selected by the user from djmax_ui and djmax_trial.
const MENU_SELECT = null
const SONG_SELECT = null
const CONFIRM := preload("res://assets/audio/djmax_ui/resume.wav")
const RESUME := preload("res://assets/audio/djmax_ui/resume.wav")
const PAUSE := preload("res://assets/audio/djmax_ui/score_finish.wav")
const LOADING = null
const PERFECT_COMBO := preload("res://assets/audio/djmax_trial/max_combo_original.mp3")
const STAGE_CLEAR = null
const SCORE_COUNT := preload("res://assets/audio/djmax_ui/score_count.wav")
const SCORE_FINISH := preload("res://assets/audio/djmax_ui/score_finish.wav")
const COUNTDOWN = {
	3: preload("res://assets/audio/djmax_ui/countdown_3.wav"),
	2: preload("res://assets/audio/djmax_ui/countdown_2.wav"),
	1: preload("res://assets/audio/djmax_ui/countdown_1.wav"),
	0: null,
}
