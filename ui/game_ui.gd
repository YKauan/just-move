extends CanvasLayer

# Referências aos labels principais da UI
@onready var health_label = $HealthLabel
@onready var stamina_label = $StaminaLabel
@onready var enemy_counter_label = $EnemyCounterLabel
@onready var pause_menu = $PauseMenu
@onready var event_message_label = $EventMessageLabel
@onready var fps_counter_label = $FPSCounterLabel

# Referências ao novo sistema de cards de upgrade
@onready var upgrade_card_container = $UpgradeCardContainer
@onready var upgrade_cards: Array[Node] = [
	$UpgradeCardContainer/CardHolder/UpgradeCard1,
	$UpgradeCardContainer/CardHolder/UpgradeCard2,
	$UpgradeCardContainer/CardHolder/UpgradeCard3
]

# Variáveis de controle
var world_manager: Node = null
var current_upgrades: Array = []

func _ready() -> void:
	await get_tree().process_frame
	world_manager = get_tree().get_first_node_in_group("world_manager")
	
	if world_manager == null:
		printerr("ERROR: World manager not found in 'world_manager' group.")
	
	pause_menu.hide()
	upgrade_card_container.hide()
	event_message_label.hide()
	
	# Conecta o sinal personalizado 'card_selected' de cada card
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i]
		if card and card.has_signal("card_selected"):
			print("UI: Conectando sinal 'card_selected' do UpgradeCard ", i)
			card.card_selected.connect(_on_upgrade_selected.bind(i))
		else:
			printerr("ERROR: UpgradeCard %d não é válido ou falta o sinal 'card_selected'." % i)

func _process(delta: float) -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	fps_counter_label.text = "FPS: " + str(fps)

# --- Funções para Atualizar Labels da UI ---
func update_health_label(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health

func update_stamina_label(current_stamina: int, max_stamina: int) -> void:
	stamina_label.text = "Stamina: %d/%d" % [current_stamina, max_stamina]

func update_enemy_counter(count: int) -> void:
	enemy_counter_label.text = "Enemies: %d" % count

# --- Funções para Gerenciamento de Menus e Upgrades ---
func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused

func show_upgrade_screen(upgrades: Array) -> void:
	current_upgrades = upgrades
	upgrade_card_container.show()
	
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i]
		if i < upgrades.size():
			if card and card.has_method("update_card_data"):
				card.update_card_data(upgrades[i])
				card.show()
			else:
				printerr("ERROR: Cannot update card %d." % i)
				if card: card.hide()
		else:
			if card: card.hide()

func _on_upgrade_selected(index: int) -> void:
	print("UI: Sinal 'card_selected' recebido do card: ", index)
	if world_manager and index < current_upgrades.size():
		var chosen_upgrade = current_upgrades[index]
		
		var upgrade_type = chosen_upgrade.get("type", "")
		var upgrade_value = chosen_upgrade.get("value", 0.0)
		
		if upgrade_type != "":
			world_manager.apply_player_upgrade(upgrade_type, upgrade_value)
		else:
			printerr("ERROR: Tipo de upgrade vazio no índice ", index)
		
	upgrade_card_container.hide()

# --- Funções para Mensagens de Evento ---
func show_event_message(message: String) -> void:
	event_message_label.text = message
	event_message_label.show()

func hide_event_message() -> void:
	event_message_label.hide()

func _on_resume_button_pressed() -> void:
	if world_manager:
		world_manager.toggle_pause()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")
