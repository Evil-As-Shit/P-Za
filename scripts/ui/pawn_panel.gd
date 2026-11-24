class_name PawnPanel
extends PanelContainer
## The inspect panel for the selected pawn: name and traits over tabs: Needs (mood, stress,
## energy, social, and any break or breakdown), Mood (mood effects), Social (opinions of the
## others), Skills (each level and practice toward the next) and Pay (their wage, what they
## think they deserve, and any raise they've asked for).

signal close_requested
## The player changed the pawn's hourly wage with the Pay tab's buttons.
signal wage_change_requested(pawn: Pawn, wage: float)
## The player gave (`give`) or turned down the raise the pawn asked for.
signal raise_answered(pawn: Pawn, give: bool)

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
@onready var _status: Label = %Status
@onready var _tabs: TabContainer = %Tabs
@onready var _wage_down: Button = %WageDown
@onready var _wage_up: Button = %WageUp
@onready var _wage_value: Label = %WageValue
@onready var _fair_wage: Label = %FairWage
@onready var _pay_mood: Label = %PayMood
@onready var _raise: HBoxContainer = %Raise
@onready var _give_raise: Button = %GiveRaise
@onready var _turn_down: Button = %TurnDown


func _ready() -> void:
	_close.pressed.connect(close_requested.emit)
	_wage_down.pressed.connect(_step_wage.bind(-1))
	_wage_up.pressed.connect(_step_wage.bind(1))
	_give_raise.pressed.connect(func() -> void: raise_answered.emit(pawn, true))
	_turn_down.pressed.connect(func() -> void: raise_answered.emit(pawn, false))


func _process(_delta: float) -> void:
	if visible and pawn != null:
		_update_mood()
		_update_skills()
		_update_pay()


func _step_wage(steps: int) -> void:
	if pawn == null or pawn.pay_rules == null:
		return
	wage_change_requested.emit(pawn, pawn.hourly_wage + steps * pawn.pay_rules.wage_step)


func _update_pay() -> void:
	_wage_value.text = "%s/h" % ShopFinances.format_money(pawn.hourly_wage)
	var has_rules: bool = pawn.pay_rules != null
	_wage_down.disabled = not has_rules or pawn.hourly_wage <= pawn.pay_rules.min_wage
	_wage_up.disabled = not has_rules
	_fair_wage.text = "Thinks they deserve %s/h" % ShopFinances.format_money(pawn.get_fair_wage())
	_pay_mood.text = get_pay_mood_line(pawn)
	_raise.visible = pawn.wants_raise()


## "Underpaid -6", "Well paid +4" or "Fairly paid".
static func get_pay_mood_line(of: Pawn) -> String:
	var mood: int = roundi(of.get_pay_mood())
	if mood < 0:
		return "Underpaid %+d" % mood
	if mood > 0:
		return "Well paid %+d" % mood
	return "Fairly paid"


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
	_update_pay()
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
		_status.text = ""
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
	var status: PackedStringArray = []
	if mood.is_on_breakdown():
		status.append("Having a breakdown (no work)")
	if pawn.is_resting():
		status.append("On a break")
	elif mood.is_on_standing_break():
		status.append("On a break (no break table free)")
	_status.text = "\n".join(status)
	var lines: PackedStringArray = []
	if roundi(pawn.get_pay_mood()) != 0:
		lines.append(get_pay_mood_line(pawn))
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
