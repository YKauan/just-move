extends RefCounted

# Variaveis de Sincronizacao
var mutex: Mutex
var work_semaphore: Semaphore
var result_semaphore: Semaphore

# Variaveis de Dados
var input_data: Array = []
var output_data: Array = []
var should_exit: bool = false

# Funcao principal da thread que fica em loop
func work_loop():
	while true:
		# Espera por trabalho
		work_semaphore.wait()

		# Checa se deve sair do loop e encerrar a thread
		mutex.lock()
		if should_exit:
			mutex.unlock()
			break
		mutex.unlock()

		# Pega os dados de entrada e processa
		var current_batch = []
		mutex.lock()
		current_batch = input_data
		
		# Limpa para o proximo ciclo
		input_data = []
		mutex.unlock()

		var results = []
		if not current_batch.is_empty():

			for data in current_batch:
				var enemy_pos = data["pos"]
				var player_pos = data["player_pos"]
				
				# ALGORITMO: Simples perseguição por enquanto.
				# No futuro, aqui entraria o A* ou outra lógica complexa.
				var direction = (player_pos - enemy_pos).normalized()
				
				results.append({"id": data["id"], "direction": direction})

		# Guarda os resultados de forma segura
		mutex.lock()
		output_data = results
		mutex.unlock()

		# Avisa a thread principal que os resultados estao prontos
		result_semaphore.post()

	print("AI Worker thread finished.")
