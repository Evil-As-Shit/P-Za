class_name HiringPanel
extends PanelContainer
## The resume stack: one card per applicant with their name, each skill as a rough band,
## their asking wage and how many days the resume has left, with Hire and Pass buttons.
## Reports the player's picks.

signal hire_requested(applicant: Applicant)
signal pass_requested(applicant: Applicant)

@onready var _resumes: VBoxContainer = %Resumes
@onready var _empty: Label = %Empty

## Applicant -> their card's Hire button (for tests and refreshes).
var _hire_buttons: Dictionary[Applicant, Button] = {}
var _pass_buttons: Dictionary[Applicant, Button] = {}


## Shows `hiring`'s resumes as of `day`.
func show_resumes(hiring: Hiring, day: int) -> void:
	for child: Node in _resumes.get_children():
		_resumes.remove_child(child)
		child.queue_free()
	_hire_buttons.clear()
	_pass_buttons.clear()
	var resumes: Array[Applicant] = hiring.get_resumes()
	_empty.visible = resumes.is_empty()
	for applicant: Applicant in resumes:
		_resumes.add_child(_make_card(applicant, hiring, day))


func _make_card(applicant: Applicant, hiring: Hiring, day: int) -> Control:
	var card := VBoxContainer.new()
	var header := HBoxContainer.new()
	card.add_child(header)
	var title := Label.new()
	title.text = applicant.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var wage := Label.new()
	wage.text = "Asks %s/h" % ShopFinances.format_money(applicant.asking_wage)
	header.add_child(wage)

	var skills := Label.new()
	skills.add_theme_font_size_override(&"font_size", 11)
	skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: PackedStringArray = []
	for work_type: WorkType in applicant.skills:
		lines.append("%s: %s" % [work_type.display_name, hiring.rules.get_band(applicant.skills[work_type])])
	skills.text = ", ".join(lines)
	card.add_child(skills)

	var footer := HBoxContainer.new()
	card.add_child(footer)
	var days_left := Label.new()
	var left: int = hiring.get_days_left(applicant, day)
	days_left.text = "%d day%s left" % [left, "" if left == 1 else "s"]
	days_left.add_theme_font_size_override(&"font_size", 11)
	days_left.modulate = Color(1, 1, 1, 0.6)
	days_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(days_left)
	var hire := Button.new()
	hire.text = "Hire"
	hire.focus_mode = Control.FOCUS_NONE
	hire.pressed.connect(hire_requested.emit.bind(applicant))
	footer.add_child(hire)
	var pass_button := Button.new()
	pass_button.text = "Pass"
	pass_button.focus_mode = Control.FOCUS_NONE
	pass_button.pressed.connect(pass_requested.emit.bind(applicant))
	footer.add_child(pass_button)
	_hire_buttons[applicant] = hire
	_pass_buttons[applicant] = pass_button
	card.add_child(HSeparator.new())
	return card


func get_hire_button(applicant: Applicant) -> Button:
	return _hire_buttons.get(applicant)


func get_pass_button(applicant: Applicant) -> Button:
	return _pass_buttons.get(applicant)
