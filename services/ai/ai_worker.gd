# services/ai/ai_worker.gd
# Este script é um RefCounted, não um Node. Ele apenas faz cálculos.
extends RefCounted

var nav_grid: NavigationGrid

# Variáveis de Sincronização
var mutex: Mutex
var work_semaphore: Semaphore  # A thread principal "posta" para acordar
var result_semaphore: Semaphore # O worker "posta" para avisar que terminou

# Variáveis de Dados
var input_data: Array = []  # Dados enviados pela thread principal
var output_data: Array = [] # Resultados para a thread principal
var should_exit: bool = false

# Função principal da thread, que fica em loop
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
				
				# Se temos um grid configurado, usa o A*
				if nav_grid:
					direction = nav_grid.get_next_path_position(enemy_pos, player_pos)
				else:
					# Fallback de segurança caso o nav_grid seja nulo (não deve acontecer se configurado)
					direction = (player_pos - enemy_pos).normalized()
				
				# Se por algum milagre ainda for zero, força movimento para não travar
				if direction == Vector2.ZERO:
					direction = (player_pos - enemy_pos).normalized()

				results.append({"id": data["id"], "direction": direction})
				
				results.append({"id": data["id"], "direction": direction})

		mutex.lock()
		output_data = results
		mutex.unlock()
		result_semaphore.post()

	print("AI Worker thread finished.")
