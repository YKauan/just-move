extends Node2D

# Variaveis do mundo
@export_category("Variables World")
@export var player_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] 
@export var enemy_spawn_weights: Array[float]
@export var room_scenes: Array[PackedScene]
@export var max_rooms = 3

@onready var room_container = $RoomContainer
@onready var game_ui = $GameUI

var is_paused = false
var current_room_index = -1
var enemies_to_spawn = 5
var current_enemies = 0
var player_instance: Node
var all_possible_upgrades: Array = []

func _ready() -> void:
	# Carrega os upgrades contidos no json
	load_upgrades_from_json()
	
	if enemy_scenes.is_empty() or enemy_scenes.size() != enemy_spawn_weights.size():
		printerr("Erro: enemy_scenes e enemy_spawn_weights devem ter o mesmo tamanho e nao estarem vazios.")
		get_tree().quit()

	player_instance = player_scene.instantiate()
	player_instance.global_position = Vector2(100, 100)
	add_child(player_instance)
	
	if player_instance: # Verifica se player_instance e valido
		game_ui.update_health_label(player_instance.current_health)
		game_ui.update_stamina_label(player_instance.current_stamina, player_instance.max_stamina)
	
	if game_ui.has_method("connect_player_signals"):
		game_ui.connect_player_signals(player_instance)
	else:
		player_instance.health_updated.connect(game_ui.update_health_label)

	player_instance.died.connect(_on_player_died, Node.CONNECT_DEFERRED)
	add_to_group("world_manager")
	call_deferred("load_next_room")

# Funcao dedicada para carregar e validar o JSON de upgrades
func load_upgrades_from_json() -> void:
	var path = "res://assets/upgrades/upgrades.json"
	
	if not FileAccess.file_exists(path):
		printerr("ERRO FATAL: Arquivo de upgrades nao encontrado em ", path)
		get_tree().quit()
		return

	# Acessando o arquivo
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	# Faz o parse do Json
	var json = JSON.new()
	var error = json.parse(content)
	
	# Verifica se deu certo o parse do JSON
	if error != OK:
		printerr("ERRO FATAL: Falha ao parsear o arquivo JSON de upgrades. Erro: ", json.get_error_message(), " na linha ", json.get_error_line())
		get_tree().quit()
		return
		
	var data = json.get_data()
	
	# 
	if typeof(data) == TYPE_ARRAY:
		all_possible_upgrades = data
		print("Upgrades carregados com sucesso do JSON!")
	else:
		printerr("ERRO FATAL: O arquivo JSON de upgrades nao contem um Array na raiz.")
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

# Funcao que lida com o pause
func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	game_ui.toggle_pause_menu(is_paused)
	
# Funcao para spwanar os inimigos
func spawn_enemies() -> void:
	var spawn_points = room_container.get_child(0).find_children("*", "Marker2D")
	spawn_points.shuffle()
	var actual_enemies_to_spawn = min(enemies_to_spawn, spawn_points.size())
	current_enemies = actual_enemies_to_spawn
	game_ui.update_enemy_counter(current_enemies)

	for i in range(actual_enemies_to_spawn):
		var enemy_to_instantiate = pick_random_enemy_type()
		if not enemy_to_instantiate:
			printerr("Erro: Nenhum tipo de inimigo válido selecionado para spawn.")
			continue

		var enemy = enemy_to_instantiate.instantiate()
		enemy.global_position = spawn_points[i].global_position
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)

# Envia inimigos de forma aleatoria
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

# Quando um inimigo morrer
func _on_enemy_died() -> void:
	current_enemies -= 1
	game_ui.update_enemy_counter(current_enemies)
	
	if current_enemies <= 0:
		if current_room_index >= max_rooms - 1:
			get_tree().paused = false
			SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")
		else:
			game_ui.show_upgrade_screen(get_random_upgrades())
			get_tree().paused = true

# Pega os upgrades de forma aleatoria
func get_random_upgrades() -> Array:
	# --- CORRIGIDO: Agora verifica se os upgrades foram carregados ---
	if all_possible_upgrades.is_empty():
		printerr("Aviso: Tentando obter upgrades, mas a lista está vazia. O JSON foi carregado corretamente?")
		return [] # Retorna um array vazio para evitar crash
		
	all_possible_upgrades.shuffle()
	return all_possible_upgrades.slice(0, 3)

# Aplica o upgrade escolhido pelo player
func apply_player_upgrade(type: String, value: float):
	if player_instance:
		player_instance.apply_upgrade(type, value)
	
	load_next_room()

func load_next_room() -> void:
	if room_container.get_child_count() > 0:
		room_container.get_child(0).queue_free()

	current_room_index = (current_room_index + 1) % room_scenes.size()
	var room = room_scenes[current_room_index].instantiate()
	room_container.add_child(room)
	
	enemies_to_spawn += 2
	spawn_enemies()
	get_tree().paused = false

# Quando o player morrer vai para a cena do menu
func _on_player_died() -> void:
	get_tree().paused = false
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")
