extends Node2D

# Variaveis do mundo
@export_category("Variables World")
@export var player_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] 
@export var enemy_spawn_weights: Array[float]

# Variaveis de controle do spawn ao redor do player
@export var spawn_radius_min: float = 400.0
@export var spawn_radius_max: float = 600.0

@export_category("Wave Control")
@export var initial_enemies_in_wave: int = 5
@export var enemy_increase_min: int = 3
@export var enemy_increase_max: int = 7
@export var spawn_interval: float = 1.0

@export_category("Random Events")
@export var event_wave_interval_min: int = 3 
@export var event_wave_interval_max: int = 7 
@export var event_chance: float = 0.75

@onready var game_ui = $GameUI
@onready var spawn_timer = $SpawnTimer

var is_paused: bool = false
var player_instance: CharacterBody2D
var all_possible_upgrades: Array = []
var all_possible_events: Array = []
var current_active_event: Dictionary = {}

var current_wave: int = 0
var next_event_wave: int = 0

var enemies_to_spawn_this_wave: int = 0
var enemies_spawned_this_wave: int = 0
var enemies_alive_in_wave: int = 0

func _ready() -> void:
	# Carrega upgrades e eventos do JSON
	load_upgrades_from_json()
	load_random_events_from_json()
	
	# Verifica se as configuracoes de inimigos estao corretas
	if enemy_scenes.is_empty() or enemy_scenes.size() != enemy_spawn_weights.size():
		printerr("Erro: enemy_scenes e enemy_spawn_weights devem ter o mesmo tamanho e não estarem vazios.")
		get_tree().quit()

	# Instancia e adiciona o jogador a cena
	player_instance = player_scene.instantiate()
	player_instance.global_position = Vector2(100, 100) # Posição inicial
	add_child(player_instance)
	
	# Configura conexoes do jogador com a UI
	setup_player_connections()
	
	# Adiciona o World ao grupo world_manager
	add_to_group("world_manager")
	
	# Conecta o sinal de timeout do timer de spawn
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	
	# Inicia o jogo e o ciclo de ondas
	start_game()

# Configura as conexoes do jogador com a UI
func setup_player_connections():
	if player_instance:
		# Conecta os sinais de vida e stamina
		player_instance.health_updated.connect(game_ui.update_health_label)
		player_instance.stamina_updated.connect(game_ui.update_stamina_label)
		
		# Atualiza a UI
		game_ui.update_health_label(player_instance.current_health)
		game_ui.update_stamina_label(player_instance.current_stamina, player_instance.max_stamina)

	player_instance.died.connect(_on_player_died, Node.CONNECT_DEFERRED)

# Inicia o jogo configurando a primeira onda
func start_game():
	next_event_wave = randi_range(event_wave_interval_min, event_wave_interval_max)
	print("Próximo evento aleatório agendado para a onda: ", next_event_wave)
	start_next_wave()

# Inicia a proxima onda de inimigos
func start_next_wave():
	# Encerra qualquer evento ativo da onda anterior se houver
	if not current_active_event.is_empty():
		end_current_event()
		
	current_wave += 1
	print("Iniciando Onda ", current_wave)
	
	# Checa se e hora de um novo evento aleatorio
	if current_wave >= next_event_wave:
		check_for_random_event()
		
	# Calcula quantos inimigos tera esta onda
	if current_wave == 1:
		enemies_to_spawn_this_wave = initial_enemies_in_wave
	else:
		var increase = randi_range(enemy_increase_min, enemy_increase_max)
		enemies_to_spawn_this_wave += increase
		
	# Reseta os contadores da onda
	enemies_spawned_this_wave = 0
	enemies_alive_in_wave = enemies_to_spawn_this_wave
	
	# Atualiza a UI com o novo contador de inimigos
	game_ui.update_enemy_counter(enemies_alive_in_wave)
	
	# Inicia o timer para spawnar inimigos individualmente
	spawn_timer.start(spawn_interval)

# Timer para spwanar os inimigos
func _on_spawn_timer_timeout():
	# Garante que o jogador ainda existe e que ainda ha inimigos para spawnar nesta onda
	if not is_instance_valid(player_instance):
		spawn_timer.stop()
		return

	if enemies_spawned_this_wave >= enemies_to_spawn_this_wave:
		spawn_timer.stop()
		return

	# Seleciona um tipo de inimigo e uma posicao de spawn
	var enemy_to_instantiate = pick_random_enemy_type()
	
	if not enemy_to_instantiate:
		printerr("Erro ao tentar spawnar: tipo de inimigo invalido.")
		return
		
	var spawn_position = get_random_spawn_position()
	
	# Instancia, configura e adiciona o inimigo a cena
	var enemy = enemy_to_instantiate.instantiate()
	enemy.global_position = spawn_position
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	
	# Se houver um evento ativo que afete inimigos, aplica ele ao novo inimigo
	if not current_active_event.is_empty() and current_active_event.get("type") == "enemy_effect":
		apply_enemy_event_effect(enemy, current_active_event.get("effect", {}))
		
	enemies_spawned_this_wave += 1

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
		
		if not current_active_event.is_empty():
			end_current_event()
			
		get_tree().paused = true
		game_ui.show_upgrade_screen(get_random_upgrades())

# Aplica um upgrade ao player
func apply_player_upgrade(type: String, value: float):
	if player_instance:
		player_instance.apply_upgrade(type, value)
	
	get_tree().paused = false
	start_next_wave()

func check_for_random_event() -> void:
	if all_possible_events.is_empty():
		return
	
	if randf() < event_chance:
		var chosen_event = all_possible_events.pick_random()
		apply_random_event(chosen_event)
		
	next_event_wave = current_wave + randi_range(event_wave_interval_min, event_wave_interval_max)
	print("Proximo evento aleatorio agendado para a onda: ", next_event_wave)

# Aplica um evento aleatorio
func apply_random_event(event_data: Dictionary) -> void:
	# Encerra qualquer evento ativo antes de iniciar um novo
	if not current_active_event.is_empty():
		end_current_event()
		
	current_active_event = event_data
	
	print("EVENTO ATIVO: ", event_data.get("text", "Evento Desconhecido"))
	game_ui.show_event_message(event_data.get("text", "Evento Desconhecido"))
	
	var effect = event_data.get("effect", {})
	match event_data.get("type"):
		"player_effect":
			apply_player_event_effect(player_instance, effect)
		"enemy_effect":
			# Aplica o efeito a inimigos ja existentes
			for enemy in get_tree().get_nodes_in_group("enemy"):
				apply_enemy_event_effect(enemy, effect)
		"puzzle_level":
			# Logica futura para puzzles
			printerr("Evento de tipo 'puzzle_level' não implementado ainda.")
		_ :
			printerr("Tipo de evento desconhecido: ", event_data.get("type"))

# Aplica evento no jogador
func apply_player_event_effect(player_node: CharacterBody2D, effect_data: Dictionary) -> void:
	if not is_instance_valid(player_node): return
	
	if effect_data.has("input_modifier"):
		player_node.set_input_modifier(effect_data.input_modifier)
	if effect_data.has("move_speed_multiplier"):
		player_node.set_move_speed_multiplier(effect_data.move_speed_multiplier)
	if effect_data.has("dash_speed_multiplier"):
		player_node.set_dash_speed_multiplier(effect_data.dash_speed_multiplier)
	if effect_data.has("damage_taken_multiplier"):
		player_node.set_damage_taken_multiplier(effect_data.damage_taken_multiplier)
	if effect_data.has("can_shoot"):
		player_node.set_can_shoot(effect_data.can_shoot)
	if effect_data.has("can_melee"):
		player_node.set_can_melee(effect_data.can_melee)

# Aplica evento nos inimigos
func apply_enemy_event_effect(enemy_node: CharacterBody2D, effect_data: Dictionary) -> void:
	if not is_instance_valid(enemy_node): return
	
	if enemy_node.has_method("set_invincible_status") and effect_data.has("invincible"):
		enemy_node.set_invincible_status(effect_data.invincible)

# Reverte os efeitos do evento ativo
func end_current_event() -> void:
	# Nenhum evento ativo para encerrar
	if current_active_event.is_empty(): return 
	
	print("EVENTO ENCERRADO: ", current_active_event.get("text", "Evento Desconhecido"))
	game_ui.hide_event_message() 
	
	var effect = current_active_event.get("effect", {})
	match current_active_event.get("type"):
		"player_effect":
			revert_player_event_effect(player_instance, effect)
		"enemy_effect":
			for enemy in get_tree().get_nodes_in_group("enemy"):
				revert_enemy_event_effect(enemy, effect)
		_ :
			pass
	 
	# Limpa o evento ativo		
	current_active_event = {}

# Reverte evento no jogador
func revert_player_event_effect(player_node: CharacterBody2D, effect_data: Dictionary) -> void:
	if not is_instance_valid(player_node): return
	
	if effect_data.has("input_modifier"):
		player_node.set_input_modifier("none")
	if effect_data.has("move_speed_multiplier"):
		player_node.reset_move_speed_multiplier()
	if effect_data.has("dash_speed_multiplier"):
		player_node.reset_dash_speed_multiplier()
	if effect_data.has("damage_taken_multiplier"):
		player_node.reset_damage_taken_multiplier()
	if effect_data.has("can_shoot"):
		player_node.set_can_shoot(true)
	if effect_data.has("can_melee"):
		player_node.set_can_melee(true)

# Reverte evento nos inimigos
func revert_enemy_event_effect(enemy_node: CharacterBody2D, effect_data: Dictionary) -> void:
	if not is_instance_valid(enemy_node): return
	
	if enemy_node.has_method("set_invincible_status") and effect_data.has("invincible"):
		enemy_node.set_invincible_status(false)

# Carrega os upgrades
func load_upgrades_from_json() -> void:
	var path = "res://data/upgrades/upgrades.json"
	if not FileAccess.file_exists(path):
		printerr("ERRO FATAL: Arquivo de upgrades não encontrado em ", path)
		get_tree().quit()
		return
	var file = FileAccess.open(path, FileAccess.READ)
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

# Carrega os eventos
func load_random_events_from_json() -> void:
	var path = "res://data/events/random_events.json"
	if not FileAccess.file_exists(path):
		printerr("ERRO FATAL: Arquivo de eventos aleatórios não encontrado em ", path)
		get_tree().quit()
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	if json.parse(content) == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_ARRAY:
			all_possible_events = data
			print("Eventos aleatórios carregados com sucesso do JSON!")
		else:
			printerr("ERRO FATAL: O arquivo JSON de eventos aleatórios não contém um Array na raiz.")
			get_tree().quit()
	else:
		printerr("ERRO FATAL: Falha ao parsear o arquivo JSON de eventos aleatórios.")
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

# Ativa / Desativa o pause do jogo
func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	game_ui.toggle_pause_menu(is_paused)

# Seleciona um evento aleatorio
func pick_random_enemy_type() -> PackedScene:
	var total_weight = 0.0
	for weight in enemy_spawn_weights:
		total_weight += weight
	var random_value = randf() * total_weight
	var current_weight_sum = 0.0
	for i in range(enemy_scenes.size()):
		current_weight_sum += enemy_spawn_weights[i]
		if random_value <= current_weight_sum:
			return enemy_scenes[i]
	return null

# Seleciona um upgrade
func get_random_upgrades() -> Array:
	if all_possible_upgrades.is_empty():
		printerr("Aviso: Tentando obter upgrades, mas a lista esta vazia.")
		return []
	all_possible_upgrades.shuffle()
	return all_possible_upgrades.slice(0, 3)

# Quando o player morrer
func _on_player_died() -> void:
	get_tree().paused = false
	
	if not current_active_event.is_empty():
		end_current_event()
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")
