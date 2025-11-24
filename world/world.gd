# world/world.gd
extends Node2D

var nav_grid: NavigationGrid
var debug_enemy_lines: Array = [] # Para desenhar linhas de debug

@export_category("World Dependencies")
@export var player_scene: PackedScene
@onready var game_ui = $GameUI
@onready var spawn_timer = $SpawnTimer
@onready var enemy_ai_service = $EnemyAIService
@onready var wave_manager = $WaveManager

@export_category("Enemy Spawning")
@export var enemy_scenes: Array[PackedScene] 
@export var enemy_spawn_weights: Array[float]
@export var spawn_radius_min: float = 100.0
@export var spawn_radius_max: float = 300.0

@export_category("Wave Control")
@export var initial_enemies_in_wave: int = 5
@export var enemy_increase_min: int = 3
@export var enemy_increase_max: int = 7
@export var spawn_interval: float = 1.0
@export var ai_update_interval: float = 0.2 # Frequência de atualização da IA

@export_category("Random Events")
@export var event_wave_interval_min: int = 3 
@export var event_wave_interval_max: int = 7 
@export var event_chance: float = 0.75

var is_paused: bool = false
var player_instance: CharacterBody2D
var all_possible_upgrades: Array = []
var all_possible_events: Array = []
var current_active_event: Dictionary = {}
var ai_update_timer: float = 0.0

var current_wave: int = 0
var next_event_wave: int = 0

var wave_spawn_list: Array = [] # Lista de inimigos pré-calculada pela thread
var enemies_spawned_this_wave: int = 0
var enemies_alive_in_wave: int = 0


func _ready() -> void:
	load_upgrades_from_json()
	
	if enemy_scenes.is_empty() or enemy_scenes.size() != enemy_spawn_weights.size():
		printerr("Erro: enemy_scenes e enemy_spawn_weights devem ter o mesmo tamanho e não estarem vazios.")
		get_tree().quit()

	player_instance = player_scene.instantiate()
	player_instance.global_position = Vector2(100, 100)
	add_child(player_instance)
	
	# Inicializa o Grid A*
	nav_grid = NavigationGrid.new()
	# Cria um grid de 100x100 células (ajuste conforme o tamanho do seu mapa)
	# Centralizado no (0,0) ou onde for seu mapa.
	# Exemplo: Mapa de 3200x3200 pixels (100 células de 32px)
	var map_rect = Rect2i(-100, -100, 200, 200)
	nav_grid.setup_grid(map_rect, []) # Passa lista vazia se não tiver paredes ainda
	
	# Passa o grid para o serviço de IA
	enemy_ai_service.setup(nav_grid)

	setup_player_connections()
	add_to_group("world_manager")
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	enemy_ai_service.ai_calculations_finished.connect(_on_ai_calculations_finished)
	wave_manager.wave_calculated.connect(_on_wave_calculated)
	
	start_game()

func _physics_process(delta):
	# Se o jogo não está pausado, atualiza o timer da IA
	if not get_tree().paused:
		ai_update_timer += delta
		if ai_update_timer >= ai_update_interval:
			ai_update_timer = 0.0
			request_ai_update_from_service()

func setup_player_connections():
	if player_instance:
		player_instance.health_updated.connect(game_ui.update_health_label)
		player_instance.stamina_updated.connect(game_ui.update_stamina_label)
		
		game_ui.update_health_label(player_instance.current_health)
		game_ui.update_stamina_label(player_instance.current_stamina, player_instance.max_stamina)

	player_instance.died.connect(_on_player_died, Node.CONNECT_DEFERRED)

func start_game():
	next_event_wave = randi_range(event_wave_interval_min, event_wave_interval_max)
	print("Próximo evento aleatório agendado para a onda: ", next_event_wave)
	start_next_wave()

func start_next_wave():
	current_wave += 1
	print("Calculando Onda ", current_wave, "...")

	# Prepara os dados e pede para o WaveManager calcular em uma thread
	var wave_data = {
		"current_wave": current_wave,
		"initial_enemies": initial_enemies_in_wave,
		"increase_min": enemy_increase_min,
		"increase_max": enemy_increase_max,
		"last_wave_enemy_count": wave_spawn_list.size(),
		"enemy_scenes": enemy_scenes,
		"enemy_weights": enemy_spawn_weights
	}
	wave_manager.request_next_wave_calculation(wave_data)

# Chamado quando a thread do WaveManager termina
func _on_wave_calculated(spawn_data: Array):
	print("Onda ", current_wave, " calculada. Inimigos a spawnar: ", spawn_data.size())
	wave_spawn_list = spawn_data
	enemies_spawned_this_wave = 0
	enemies_alive_in_wave = wave_spawn_list.size()
	game_ui.update_enemy_counter(enemies_alive_in_wave)
	spawn_timer.start(spawn_interval)
	
# Spawna um inimigo da lista pré-calculada
func _on_spawn_timer_timeout():
	if enemies_spawned_this_wave >= wave_spawn_list.size():
		spawn_timer.stop()
		return
		
	var spawn_info = wave_spawn_list[enemies_spawned_this_wave]
	var enemy = spawn_info["scene"].instantiate()
	enemy.global_position = get_random_spawn_position()
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	
	enemies_spawned_this_wave += 1

# Pede para o serviço de IA calcular as direções
func request_ai_update_from_service():
	if not is_instance_valid(player_instance):
		return
		
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
		
	var enemy_data_for_thread: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy_data_for_thread.append({"id": enemy.get_instance_id(), "pos": enemy.global_position})
	
	enemy_ai_service.request_ai_update(enemy_data_for_thread, player_instance.global_position)

# Chamado quando a thread de IA termina
func _on_ai_calculations_finished(results: Array):
	debug_enemy_lines.clear() # Limpa linhas antigas
	
	for result in results:
		var enemy_id = result["id"]
		var direction = result["direction"]
		
		var enemy_node = instance_from_id(enemy_id)
		if is_instance_valid(enemy_node):
			enemy_node.set_movement_direction(direction)
			# Adiciona linha de debug (Do inimigo -> Direção calculada)
			# Salva apenas 1 a cada 10 para não poluir a tela
			if randi() % 10 == 0:
				debug_enemy_lines.append({
					"start": enemy_node.global_position,
					"end": enemy_node.global_position + (direction * 50)
				})
	queue_redraw()

# Calcula uma posicao de spawn aleatoria ao redor do jogador
func get_random_spawn_position() -> Vector2:
	if not is_instance_valid(player_instance):
		return Vector2.ZERO

	var random_angle = randf() * TAU
	var random_distance = randf_range(spawn_radius_min, spawn_radius_max)
	var offset = Vector2(cos(random_angle), sin(random_angle)) * random_distance
	
	return player_instance.global_position + offset

# Funcao para quando o inimigo morrer
func _on_enemy_died() -> void:
	enemies_alive_in_wave -= 1
	game_ui.update_enemy_counter(enemies_alive_in_wave)
	
	if enemies_alive_in_wave <= 0:
		print("Onda ", current_wave, " concluída!")
			
		get_tree().paused = true
		game_ui.show_upgrade_screen(get_random_upgrades())

# Aplica um upgrade ao player
func apply_player_upgrade(type: String, value: float):
	if player_instance:
		player_instance.apply_upgrade(type, value)
	
	get_tree().paused = false
	start_next_wave() # Inicia a próxima onda

# --- Funções de Carregamento de JSON (sem alteração) ---
func load_upgrades_from_json():
	var path = "res://data/upgrades/upgrades.json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("ERRO FATAL: Arquivo de upgrades não encontrado em ", path)
		get_tree().quit()
		return
	var content = file.get_as_text()
	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_ARRAY:
			all_possible_upgrades = data
			print("Upgrades carregados com sucesso do JSON!")
		else:
			printerr("ERRO FATAL: O arquivo JSON de upgrades não contém um Array na raiz.")
			get_tree().quit()
	else:
		printerr("ERRO FATAL: Falha ao parsear o arquivo JSON de upgrades.")
		get_tree().quit()

# --- Funções de UI, Input e Outros (sem alteração) ---
func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	is_paused = not is_paused
	get_tree().paused = is_paused
	game_ui.toggle_pause_menu(is_paused)

func pick_random_enemy_type() -> PackedScene:
	# Esta função agora é chamada pela thread do WaveManager,
	# mas como ela é estática (não depende de 'self' como um Node),
	# podemos deixá-la aqui para referência, mas o WaveManager
	# tem sua própria cópia dela.
	var total_weight = 0.0
	for weight in enemy_spawn_weights: total_weight += weight
	if total_weight == 0.0: return null
	var random_value = randf() * total_weight
	var current_weight_sum = 0.0
	for i in range(enemy_scenes.size()):
		current_weight_sum += enemy_spawn_weights[i]
		if random_value <= current_weight_sum:
			return enemy_scenes[i]
	return null

func get_random_upgrades() -> Array:
	if all_possible_upgrades.is_empty():
		printerr("Aviso: Tentando obter upgrades, mas a lista esta vazia.")
		return []
	all_possible_upgrades.shuffle()
	return all_possible_upgrades.slice(0, 3)

func _on_player_died():
	get_tree().paused = false
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")

func _draw():

	for line in debug_enemy_lines:
		draw_line(line["start"], line["end"], Color.CYAN, 2.0)
		draw_circle(line["end"], 2.0, Color.CYAN)
