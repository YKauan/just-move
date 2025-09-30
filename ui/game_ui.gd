extends CanvasLayer

# Pego os labels
@onready var health_label = $HealthLabel
@onready var stamina_label = $StaminaLabel
@onready var enemy_counter_label = $EnemyCounterLabel
@onready var upgrade_screen = $UpgradeScreen
@onready var event_message_label = $EventMessageLabel

# Pego a referencia dos botoes
@onready var upgrade_button_1 = $UpgradeScreen/VBoxContainer/UpgradeButton1
@onready var upgrade_button_2 = $UpgradeScreen/VBoxContainer/UpgradeButton2
@onready var upgrade_button_3 = $UpgradeScreen/VBoxContainer/UpgradeButton3

# Pego as referencias do menu
@onready var pause_menu = $PauseMenu
@onready var resume_button = $PauseMenu/VBoxContainer/ResumeButton
@onready var main_menu_button = $PauseMenu/VBoxContainer/MainMenuButton

var world_node: Node

# Upgrades a serem oferecidos
var current_upgrades: Array

func _ready() -> void:
	upgrade_screen.hide()
	event_message_label.hide()
	pause_menu.hide()
	
	await get_tree().process_frame
	world_node = get_tree().get_first_node_in_group("world_manager")
	
	resume_button.pressed.connect(_on_resume_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)

	# Conecta aos botoes
	upgrade_button_1.pressed.connect(_on_upgrade_selected.bind(0))
	upgrade_button_2.pressed.connect(_on_upgrade_selected.bind(1))
	upgrade_button_3.pressed.connect(_on_upgrade_selected.bind(2))

# Conecta aos sinais do player
func connect_player_signals(player_node: Node) -> void:
	if not player_node: return
	player_node.health_updated.connect(update_health_label)
	if player_node.has_signal("stamina_updated"):
		player_node.stamina_updated.connect(update_stamina_label)

# Atualiza o label de vida
func update_health_label(current_health: int) -> void:
	health_label.text = "Vida: %d" % current_health

# Atualiza o Label de stamina
func update_stamina_label(current_stamina: int, max_stamina: int) -> void:
	stamina_label.text = "Vigor: %d / %d" % [current_stamina, max_stamina]

# Atualiza o contador de inimigos restantes
func update_enemy_counter(count: int) -> void:
	enemy_counter_label.text = "Inimigos restantes: %d" % count
	
# Funcao para exibir os upgrades
func show_upgrade_screen(upgrades: Array) -> void:
	current_upgrades = upgrades
	
	# Configura o texto de cada botao
	if upgrades.size() > 0:
		upgrade_button_1.text = upgrades[0].text
	if upgrades.size() > 1:
		upgrade_button_2.text = upgrades[1].text
	if upgrades.size() > 2:
		upgrade_button_3.text = upgrades[2].text
	
	upgrade_screen.show()

# Funcao para executar o upgrade selecionado
func _on_upgrade_selected(index: int) -> void:
	if world_node and not current_upgrades.is_empty():
		var chosen_upgrade = current_upgrades[index]
		
		# Aplica o upgrade
		world_node.apply_player_upgrade(chosen_upgrade.type, chosen_upgrade.value)
	
	upgrade_screen.hide()

# Atualiza flag do menu de pause
func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused

# Despausa o jogo
func _on_resume_button_pressed() -> void:
	if world_node:
		world_node.toggle_pause()

# Volta ao menu principal
func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")

# Exibe label de evento atual
func show_event_message(message: String) -> void:
	event_message_label.text = message
	event_message_label.show()

# Esconde label de evento
func hide_event_message() -> void:
	event_message_label.hide()
