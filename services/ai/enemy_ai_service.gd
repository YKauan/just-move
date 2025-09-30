extends Node

signal ai_calculations_finished(results)

# Configuracoes da Thread Pool
@export var num_threads: int = 2 # inicia com 2

# Pool de Threads
var threads: Array[Thread] = []
var workers: Array = []

# Variaveis de Controle
var is_processing_wave: bool = false
var enemies_to_process: Array = []
var results_from_workers: Array = []
var workers_finished: int = 0

func _ready():
	# Inicia a thread pool
	for i in range(num_threads):
		var worker = preload("res://services/ai/ai_worker.gd").new()
		var thread = Thread.new()
		
		# Inicializa os mecanismos de sincronizacao
		worker.mutex = Mutex.new()
		worker.work_semaphore = Semaphore.new()
		worker.result_semaphore = Semaphore.new()
		
		# Inicia a thread que ficara esperando por trabalho
		thread.start(Callable(worker, "work_loop"))
		
		threads.append(thread)
		workers.append(worker)
	
	print("Enemy AI Service ready with %d threads." % num_threads)

# Funcao para lidar com o encerramento do jogo
func _exit_tree():
	# Garante que as threads sejam encerradas de forma segura quando o jogo fecha
	for worker in workers:
		worker.mutex.lock()
		worker.should_exit = true
		worker.mutex.unlock()
		worker.work_semaphore.post()
	
	for thread in threads:
		thread.wait_to_finish()
	print("All AI worker threads stopped.")

# Funcao principal chamada pelo World para solicitar calculos
func request_ai_update(enemies: Array, player_pos: Vector2):
	if is_processing_wave or enemies.is_empty():
		# Ignora se ja estiver processando ou nao houver inimigos
		return 

	is_processing_wave = true
	results_from_workers.clear()
	workers_finished = 0
	
	# Distribui a lista de inimigos entre as threads
	var batch_size = int(ceil(float(enemies.size()) / num_threads))
	
	for i in range(num_threads):
		var worker = workers[i]
		var start_index = i * batch_size
		var end_index = min(start_index + batch_size, enemies.size())
		
		if start_index >= enemies.size():
			# Nao ha mais inimigos para esta thread
			continue

		var batch = enemies.slice(start_index, end_index)
		
		# Adiciona a posicao do jogador a cada inimigo no lote
		for j in range(batch.size()):
			batch[j]["player_pos"] = player_pos
			
		# Envia o trabalho para a thread
		worker.mutex.lock()
		worker.input_data = batch
		worker.mutex.unlock()
		worker.work_semaphore.post()

		# Inicia a espera pelo resultado desta thread
		await worker.result_semaphore.wait()
		
		# Coleta os resultados
		worker.mutex.lock()
		results_from_workers.append_array(worker.output_data)
		worker.mutex.unlock()
		
		workers_finished += 1

	# Quando todas as threads terminarem
	if workers_finished >= num_threads:
		emit_signal("ai_calculations_finished", results_from_workers)
		is_processing_wave = false
