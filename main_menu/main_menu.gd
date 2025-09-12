extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed() -> void:
	# Carrega a cena principal do jogo
	SceneManager.go_to_scene("res://world/world.tscn")

func _on_quit_button_pressed() -> void:
	# Fecha o jogo
	get_tree().quit()
