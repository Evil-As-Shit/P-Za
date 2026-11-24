class_name PawnPanel
extends PanelContainer
## HUD panel for the selected pawn: their traits, mood, stress, energy, social, opinions of
## the others, breaks and mood effects, and their skills, each with its level and practice
## toward the next level. Later pay too.

signal close_requested

const BAR_SIZE := Vector2(60, 6)

var pawn: Pawn = null
## Names friends and rivals in the opinions list (set by the HUD; null lists numbers only).
var social: Social = null

## Work type -> the level label and practice bar in its row.
var _levels: Dictionary[WorkType, Label] = {}
var _bars: Dictionary[WorkType, ProgressBar] = {}

@onready var _title: Label = %Title
@onready var _skills: GridContainer = %Skills
@onready var _close: Button = %Close
@onready var _traits: Label = %Traits
@onready var _mood_value: Label = %MoodValue
@onready var _mood_bar: ProgressBar = %MoodBar
@onready var _stress_value: Label = %StressValue
@onready var _stress_bar: ProgressBar = %StressBar
@onready var _energy_value: Label = %EnergyValue
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _social_value: Label = %SocialValue
@onready var _social_bar: ProgressBar = %SocialBar
@onready var _opinions: Label = %Opinions
@onready var _effects: Label = %Effects


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)


func _process(_delta: float) -> void:
	if visible and pawn != null:
		_update_mood()
		_update_skills()


func show_pawn(p_pawn: Pawn, work_types: Array[WorkType]) -> void:
	pawn = p_pawn
	_title.text = pawn.display_name
	_show_traits()
	for child: Node in _skills.get_children():
		_skills.remove_child(child)
		child.queue_free()
	_levels.clear()
	_bars.clear()
	for work_type: WorkType in work_types:
		if not work_type.has_skill:
			continue
		var skill_name := Label.new()
		skill_name.text = work_type.display_name
		skill_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_skills.add_child(skill_name)
		var level := Label.new()
		level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_skills.add_child(level)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = BAR_SIZE
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.max_value = 1.0
		bar.step = 0.0
		bar.show_percentage = false
		_skills.add_child(bar)
		_levels[work_type] = level
		_bars[work_type] = bar
	_update_mood()
	_update_skills()
	show()


## "Traits: Calm, Lazy", with what each does on hover.
func _show_traits() -> void:
	var names: PackedStringArray = []
	var details: PackedStringArray = []
	for each: PawnTrait in pawn.traits:
		names.append(each.display_name)
		details.append("%s: %s" % [each.display_name, each.description])
	_traits.text = "Traits: " + (", ".join(names) if not names.is_empty() else "none")
	_traits.tooltip_text = "\n".join(details)


## One line per pawn they have an opinion of, e.g. "Pawn 2: +56 (Friend)".
func _get_opinion_lines(mood: PawnMood) -> String:
	var lines: PackedStringArray = []
	for other: Pawn in mood.opinions:
		if not is_instance_valid(other):
			continue
		var opinion: float = mood.get_opinion(other)
		var line: String = "%s: %+d" % [other.display_name, roundi(opinion)]
		var relation: String = social.get_relation(opinion) if social != null else ""
		if relation != "":
			line += " (%s)" % relation
		lines.append(line)
	return "\n".join(lines) if not lines.is_empty() else "No opinions yet"


func _update_mood() -> void:
	var mood: PawnMood = pawn.mood
	if mood == null:
		_mood_value.text = "-"
		_mood_bar.value = 0.0
		_stress_value.text = "-"
		_stress_bar.value = 0.0
		_energy_value.text = "-"
		_energy_bar.value = 0.0
		_social_value.text = "-"
		_social_bar.value = 0.0
		_opinions.text = ""
		_effects.text = ""
		return
	_mood_value.text = "%d %s" % [roundi(mood.mood), mood.get_band_name()]
	_mood_bar.value = mood.mood
	_mood_bar.tooltip_text = "Heading toward %d" % roundi(mood.get_target())
	_stress_value.text = str(roundi(mood.stress))
	_stress_bar.value = mood.stress
	_energy_value.text = str(roundi(mood.energy))
	_energy_bar.value = mood.energy
	_social_value.text = str(roundi(mood.social))
	_social_bar.value = mood.social
	_opinions.text = _get_opinion_lines(mood)
	var lines: PackedStringArray = []
	if mood.is_on_breakdown():
		lines.append("Having a breakdown (no work)")
	if pawn.is_resting():
		lines.append("On a break")
	elif mood.is_on_standing_break():
		lines.append("On a break (no break table free)")
	var effects: Dictionary[MoodEffect, float] = mood.get_effects()
	for effect: MoodEffect in effects:
		lines.append("%s %+d (%d min)" % [effect.display_name, roundi(effect.mood), ceili(effects[effect])])
	_effects.text = "\n".join(lines) if not lines.is_empty() else "No mood effects"


func _update_skills() -> void:
	var rules: SkillRules = pawn.skill_rules
	for work_type: WorkType in _levels:
		var level: int = pawn.get_skill(work_type)
		_levels[work_type].text = str(level)
		var bar: ProgressBar = _bars[work_type]
		if level >= rules.max_level:
			bar.value = 1.0
			bar.tooltip_text = "Max level"
		else:
			var needed: float = rules.minutes_to_next(level)
			bar.value = pawn.get_practice(work_type) / needed
			bar.tooltip_text = "%d/%d min practice to level %d" % [
				int(pawn.get_practice(work_type)), int(needed), level + 1
			]
