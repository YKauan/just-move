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

var log_file_path: String = ""
var log_interval: float = 0.5 
var log_timer: float = 0.0
var is_logging: bool = true

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
	
	if is_logging and world_manager:
		setup_benchmark_file()

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
	
	if is_logging and log_file_path != "":
		log_timer += delta
		if log_timer >= log_interval:
			log_timer = 0.0
			save_to_csv()

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

func setup_benchmark_file():
	var is_single = world_manager.force_single_thread_bench
	var mode_folder = "single" if is_single else "multi"
	
	# 1. Caminho relativo (funciona dentro da engine)
	var relative_dir = "res://benchmarks/" + mode_folder + "/"
	
	# 2. Caminho Absoluto (O Godot ajusta as barras / ou \ automaticamente)
	var absolute_dir = ProjectSettings.globalize_path(relative_dir)
	
	# 3. Cria as pastas no sistema operacional
	var err = DirAccess.make_dir_recursive_absolute(absolute_dir)
	
	if err != OK:
		printerr("ERRO: Falha ao criar pastas no SO (", OS.get_name(), "): ", err)
		return

	# 4. Gera o Timestamp para o nome do arquivo
	var time_dict = Time.get_datetime_dict_from_system()
	var time_stamp = "%d_%02d_%02d_%02d%02d" % [
		time_dict.year, time_dict.month, time_dict.day, 
		time_dict.hour, time_dict.minute
	]
	
	var mode_name = "single" if is_single else "multi"
	var file_name = "benchmark_results_" + mode_name + "_" + time_stamp + ".csv"
	
	# 5. Define o caminho final do arquivo
	log_file_path = absolute_dir + file_name
	
	# Prints para depuração no console do Editor
	print("Sistema Operacional: ", OS.get_name())
	print("Local do Arquivo: ", log_file_path)
	
	var file = FileAccess.open(log_file_path, FileAccess.WRITE)
	if file:
		file.store_line("Timestamp_ms,Mode,FPS,FrameTime_ms,Entities")
		file.close()
	else:
		printerr("erro ao criar o arquivo.")
		
func save_to_csv():
	var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		var timestamp = Time.get_ticks_msec()
		var mode = "Single" if world_manager.force_single_thread_bench else "Multi"
		var fps = Performance.get_monitor(Performance.TIME_FPS)
		var ft = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var entities = get_tree().get_nodes_in_group("enemy").size()
		
		var line = "%d,%s,%.2f,%.4f,%d" % [timestamp, mode, fps, ft, entities]
		file.store_line(line)
		file.close()
