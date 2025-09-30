extends Node

signal wave_calculated(spawn_data)

var thread: Thread
var mutex: Mutex
var is_calculating: bool = false

func _ready():
	thread = Thread.new()
	mutex = Mutex.new()

# Calcula a proxima wave
func request_next_wave_calculation(wave_data: Dictionary):
	if is_calculating:
		return
		
	is_calculating = true
	thread.start(Callable(self, "_calculate_wave_thread").bind(wave_data))
	
	# Espera a thread terminar e emite o sinal
	var spawn_data = await thread.wait_to_finish()
	emit_signal("wave_calculated", spawn_data)
	is_calculating = false

# Calcula a wave
func _calculate_wave_thread(wave_data: Dictionary) -> Array:
	var current_wave = wave_data.get("current_wave", 1)
	var initial_enemies = wave_data.get("initial_enemies", 5)
	var increase_min = wave_data.get("increase_min", 3)
	var increase_max = wave_data.get("increase_max", 7)
	var enemy_scenes = wave_data.get("enemy_scenes", [])
	var enemy_weights = wave_data.get("enemy_weights", [])
	
	var enemies_to_spawn_this_wave: int
	
	if current_wave == 1:
		enemies_to_spawn_this_wave = initial_enemies
	else:
		enemies_to_spawn_this_wave = wave_data.get("last_wave_enemy_count", initial_enemies)
		enemies_to_spawn_this_wave += randi_range(increase_min, increase_max)
		
	var spawn_list: Array = []
	
	if enemy_scenes.is_empty():
		return []

	for i in range(enemies_to_spawn_this_wave):
		await get_tree().create_timer(0.001).timeout
		
		var enemy_scene = _pick_random_enemy_type(enemy_scenes, enemy_weights)
		if enemy_scene:
			spawn_list.append({"scene": enemy_scene})
			
	return spawn_list

# Funcao auxiliar para escolher tipo de inimigo
func _pick_random_enemy_type(scenes: Array, weights: Array) -> PackedScene:
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight == 0.0:
		return null

	var random_value = randf() * total_weight
	var current_weight_sum = 0.0
	for i in range(scenes.size()):
		current_weight_sum += weights[i]
		if random_value <= current_weight_sum:
			return scenes[i]
			
	return null
