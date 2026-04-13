extends RefCounted

# Removido nav_grid pois usaremos Steering
var mutex: Mutex
var work_semaphore: Semaphore 
var result_semaphore: Semaphore

var input_data: Array = [] 
var all_enemy_positions: Array = [] # Nova lista com todos para calcular separação
var output_data: Array = [] 
var should_exit: bool = false

func work_loop():
	while true:
		work_semaphore.wait()
		
		mutex.lock()
		if should_exit: 
			mutex.unlock()
			break
		
		var current_batch = input_data
		var others = all_enemy_positions # Copia local para evitar concorrência
		input_data = [] 
		mutex.unlock()

		var results = []
		for data in current_batch:
			results.append(_calculate_steering(data, others))

		mutex.lock()
		output_data = results
		mutex.unlock()
		result_semaphore.post()

func _calculate_steering(data: Dictionary, others: Array) -> Dictionary:
	var pos = data["pos"]
	var player_pos = data["player_pos"]
	var radius = 45.0 # Raio de separação (ajuste conforme o tamanho do sprite)
	
	# 1. Vetor de Perseguição (Ir para o player)
	var desired_velocity = (player_pos - pos).normalized()
	
	# 2. Vetor de Separação (Fugir de outros inimigos)
	var separation = Vector2.ZERO
	for other_pos in others:
		var dist = pos.distance_to(other_pos)
		if dist > 0 and dist < radius:
			# Força inversamente proporcional à distância
			var diff = (pos - other_pos).normalized()
			separation += diff / dist 
	
	# 3. Combinação Final
	# Aumentamos o peso da separação para a horda se espalhar organicamente
	var final_direction = (desired_velocity + (separation * 15.0)).normalized()
	
	return {"id": data["id"], "direction": final_direction}

# Atualizado para manter compatibilidade com o benchmark single-thread
func process_single_enemy(data: Dictionary, others: Array) -> Dictionary:
	return _calculate_steering(data, others)
