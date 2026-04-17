extends RefCounted

var mutex: Mutex
var work_semaphore: Semaphore 
var result_semaphore: Semaphore

var input_data: Array = [] 
var all_enemy_positions: Array = []
var output_data: Array = [] 
var should_exit: bool = false

# loop que roda em paralelo a thread principal
func work_loop():
	while true:
		#Aguarda ser acionado
		work_semaphore.wait()
		
		mutex.lock()
		if should_exit: 
			# se o jogo fechar encerra o loop
			mutex.unlock()
			break
		
		var current_batch = input_data
		var others = all_enemy_positions
		input_data = [] 
		mutex.unlock()

		var results = []
		for data in current_batch:
			results.append(_calculate_steering(data, others))

		mutex.lock()
		output_data = results
		mutex.unlock()
		result_semaphore.post()

# Funcao que faz os calculos do movimento
func _calculate_steering(data: Dictionary, others: Array) -> Dictionary:
	var pos = data["pos"]
	var player_pos = data["player_pos"]
	var radius = 45.
	
	# perseguicao do player
	var desired_velocity = (player_pos - pos).normalized()
	
	# controle para separacao para que nao fique um inimigo dentro do outro
	var separation = Vector2.ZERO
	for other_pos in others:
		var dist = pos.distance_to(other_pos)
		if dist > 0 and dist < radius:
			
			# Empurra para a direcao oposta
			var diff = (pos - other_pos).normalized()
			separation += diff / dist 
	
	# Direcao final
	var final_direction = (desired_velocity + (separation * 15.0)).normalized()
	
	return {"id": data["id"], "direction": final_direction}

func process_single_enemy(data: Dictionary, others: Array) -> Dictionary:
	return _calculate_steering(data, others)
