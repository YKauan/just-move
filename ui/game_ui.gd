extends CanvasLayer

# Referencias aos labels principais da UI
@onready var health_label = $HealthLabel
@onready var stamina_label = $StaminaLabel
@onready var enemy_counter_label = $EnemyCounterLabel
@onready var pause_menu = $PauseMenu
@onready var event_message_label = $EventMessageLabel
@onready var fps_counter_label = $FPSCounterLabel
@onready var fps_frame_time = $FrameTimeLabel
@onready var thread_label = $ThreadLabel
@onready var thread_history_label = $ThreadHistoryLabel

# Botoes do Pause
@onready var resume_button = $PauseMenu/VBoxContainer/ResumeButton
@onready var main_menu_button = $PauseMenu/VBoxContainer/MainMenuButton

# Referencias ao sistema de cards
@onready var upgrade_card_container = $UpgradeCardContainer
@onready var upgrade_cards: Array[Node] = [
	$UpgradeCardContainer/CardHolder/UpgradeCard1,
	$UpgradeCardContainer/CardHolder/UpgradeCard2,
	$UpgradeCardContainer/CardHolder/UpgradeCard3
]

var card_colors: Array[Color] = [
	Color("#5c9aff"), # Azul
	Color("#bd73ff"), # Roxo
	Color("#6aff9b")  # Verde
]

var world_manager: Node = null
var current_upgrades: Array = []

# Variaveis para a logica de cor
var previous_ft: float = 0.0
var previous_fps: float = 0.0
var previous_busy_threads: int = -1
var thread_log_history: Array = []

func _ready() -> void:
	await get_tree().process_frame
	world_manager = get_tree().get_first_node_in_group("world_manager")
	
	if world_manager == null:
		printerr("ERROR: World manager not found.")
	
	pause_menu.hide()
	upgrade_card_container.hide()
	event_message_label.hide()
	
	# Conexão de sinais dos cards
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i]
		if card and card.has_signal("card_selected"):
			card.card_selected.connect(_on_upgrade_selected.bind(i))
		else:
			printerr("ERROR: UpgradeCard %d inválido." % i)

func _process(delta: float) -> void:
	var current_fps = Performance.get_monitor(Performance.TIME_FPS)
	fps_counter_label.text = "FPS: " + str(current_fps)
	
	var frame_time_s = Performance.get_monitor(Performance.TIME_PROCESS)
	var frame_time_ms = frame_time_s * 1000.0
	
	fps_frame_time.text = "Frame Time: " + str(frame_time_ms)
	fps_frame_time.modulate = Color.GREEN
	
	if current_fps < previous_fps:
		fps_counter_label.modulate = Color.RED
	else:
		fps_counter_label.modulate = Color.GREEN
		
	if frame_time_ms < previous_ft:
		fps_frame_time.modulate = Color.RED
	else:
		fps_frame_time.modulate = Color.GREEN
	
	previous_fps = current_fps
	previous_ft = frame_time_ms

func update_thread_label(busy_threads: int, total_threads: int) -> void:
	thread_label.text = "Threads: %d/%d" % [busy_threads, total_threads]
	
	var current_color_hex: String = "00ff00"
	if busy_threads < previous_busy_threads:
		thread_label.modulate = Color.RED
		current_color_hex = "ff0000"
	else:
		thread_label.modulate = Color.GREEN
		current_color_hex = "00ff00"
		
	previous_busy_threads = busy_threads
	
	if busy_threads > 0:
		var log_entry = "[color=#%s]%d/%d[/color]" % [current_color_hex, busy_threads, total_threads]
		
		thread_log_history.push_front(log_entry)
		
		if thread_log_history.size() > 3:
			thread_log_history.pop_back()
		
		thread_history_label.text = "\n".join(thread_log_history)
	
	if total_threads == 0:
		thread_label.modulate = Color.YELLOW

func update_health_label(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health

func update_stamina_label(current_stamina: int, max_stamina: int) -> void:
	stamina_label.text = "Stamina: %d/%d" % [current_stamina, max_stamina]

func update_enemy_counter(count: int) -> void:
	enemy_counter_label.text = "Enemies: %d" % count

func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused

func show_upgrade_screen(upgrades: Array) -> void:
	current_upgrades = upgrades
	upgrade_card_container.show()
	
	card_colors.shuffle()
	
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i]
		if i < upgrades.size():
			if card and card.has_method("update_card_data"):
				card.update_card_data(upgrades[i])
				card.modulate = card_colors[i % card_colors.size()]
				card.show()
		else:
			if card: card.hide()

func _on_upgrade_selected(index: int) -> void:
	if world_manager and index < current_upgrades.size():
		var chosen_upgrade = current_upgrades[index]
		var type = chosen_upgrade.get("type", "")
		var value = chosen_upgrade.get("value", 0.0)
		
		if type != "":
			world_manager.apply_player_upgrade(type, value)
		
	upgrade_card_container.hide()

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
