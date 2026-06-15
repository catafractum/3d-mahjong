extends Node

const USE_DEV_LEVELS := true
const PROD_LEVELS_PATH := "res://data/levels.json"
const DEV_LEVELS_PATH := "res://data/levels_dev.json"
const LEVELS_PATH := DEV_LEVELS_PATH if USE_DEV_LEVELS else PROD_LEVELS_PATH
const TIMER_DURATION_SECONDS := 900

var selected_level_id := 0
var has_selected_level := false
