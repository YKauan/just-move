extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

# Inicia a cena principal do jogo
func _on_start_button_pressed() -> void:
	SceneManager.go_to_scene("res://world/world.tscn")

# Encerra o jogo
func _on_quit_button_pressed() -> void:
	get_tree().quit()
