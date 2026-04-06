# services/wave/wave_manager.gd
extends Node

signal wave_calculated(spawn_data)

var thread: Thread
var is_calculating: bool = false

@export_category("Benchmark TCC")
@export var benchmark_mode: bool = false 

func _ready():
	thread = Thread.new()

# Funcao para calcular a proxima wave
func request_next_wave_calculation(wave_data: Dictionary):
	if is_calculating:
		return
		
	is_calculating = true

	if benchmark_mode:
		var spawn_data = _perform_wave_calculation_logic(wave_data)
		_finalize_calculation(spawn_data)
	else:
		
		thread.start(Callable(self, "_run_in_thread").bind(wave_data))
		var spawn_data = await thread.wait_to_finish()
		_finalize_calculation(spawn_data)

# funcao executada ao finalizar o calculo da wave
func _finalize_calculation(spawn_data: Array):
	emit_signal("wave_calculated", spawn_data)
	is_calculating = false

# Wrapper para a Thread
func _run_in_thread(wave_data: Dictionary) -> Array:
	return _perform_wave_calculation_logic(wave_data)

# Roda em thread unica
func _perform_wave_calculation_logic(wave_data: Dictionary) -> Array:
	var current_wave = wave_data.get("current_wave", 1)
	var initial_enemies = wave_data.get("initial_enemies", 5)
	var increase_min = wave_data.get("increase_min", 3)
	var increase_max = wave_data.get("increase_max", 7)
	var enemy_scenes = wave_data.get("enemy_scenes", [])
	var enemy_weights = wave_data.get("enemy_weights", [])
	var last_wave_count = wave_data.get("last_wave_enemy_count", 0)
	
	var enemies_to_spawn_this_wave: int
	
	if current_wave == 1:
		enemies_to_spawn_this_wave = initial_enemies
	else:
		enemies_to_spawn_this_wave = last_wave_count + randi_range(increase_min, increase_max)
		
	var spawn_list: Array = []
	
	if enemy_scenes.is_empty():
		return []

	for i in range(enemies_to_spawn_this_wave):
		var enemy_scene = _pick_random_enemy_type(enemy_scenes, enemy_weights)
		if enemy_scene:
			spawn_list.append({"scene": enemy_scene})
			
	return spawn_list

# Funcao que escolhe o tipo do inimigo
func _pick_random_enemy_type(scenes: Array, weights: Array) -> PackedScene:
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight == 0.0:
		return scenes.pick_random() if not scenes.is_empty() else null

	var random_value = randf() * total_weight
	var current_weight_sum = 0.0
	for i in range(scenes.size()):
		current_weight_sum += weights[i]
		if random_value <= current_weight_sum:
			return scenes[i]
			
	return null
