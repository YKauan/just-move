extends RefCounted

var nav_grid: NavigationGrid

# Variaveis de Sincronizacao
var mutex: Mutex
var work_semaphore: Semaphore  # A thread principal posta para acordar
var result_semaphore: Semaphore # O worker posta para avisar que terminou

# Variaveis de Dados
var input_data: Array = []  # Dados otidos da thread principal
var output_data: Array = [] # Resultados retornados a thread principal
var should_exit: bool = false

func work_loop():
	while true:
		work_semaphore.wait()
		
		mutex.lock()
		var exit_now = should_exit
		mutex.unlock()
		if exit_now: break

		var current_batch = []
		mutex.lock()
		current_batch = input_data
		input_data = [] 
		mutex.unlock()

		var results = []
		if not current_batch.is_empty():
			for data in current_batch:
				var enemy_pos = data["pos"]
				var player_pos = data["player_pos"]
				
				var direction = Vector2.ZERO
				
				# Se  for usar o A* e o nav_grid estiver ok
				if nav_grid:
					direction = nav_grid.get_next_path_position(enemy_pos, player_pos)
				else:
					direction = (player_pos - enemy_pos).normalized()
				
				# Se por algum milagre ainda for zero forco para movimentar e nao travar
				if direction == Vector2.ZERO:
					direction = (player_pos - enemy_pos).normalized()

				results.append({"id": data["id"], "direction": direction})
				
				results.append({"id": data["id"], "direction": direction})

		mutex.lock()
		output_data = results
		mutex.unlock()
		result_semaphore.post()

	print("AI Worker thread finalizada.")

# Funcao para processar apenas um inimigo
func process_single_enemy(data) -> Dictionary:
	var enemy_pos = data["pos"]
	var player_pos = data["player_pos"]
	
	var dir = (player_pos - enemy_pos).normalized()
	
	return {"id": data["id"], "direction": dir}
