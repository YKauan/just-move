extends Node

signal ai_calculations_finished(results)

# Configuracoes da Thread Pool
@export var num_threads: int = 2

# Pool de Threads
var threads: Array[Thread] = []
var workers: Array = []

# Variaveis de Controle
var is_processing_wave: bool = false
var results_from_workers: Array = []
var workers_to_check: Array = [] # NOVO: Lista de workers que estão trabalhando

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


# NOVO: A função _process vai verificar os resultados sem bloquear o jogo.
func _process(_delta):
	# Se não estivermos esperando por nenhum resultado, não faz nada.
	if workers_to_check.is_empty():
		return

	var still_working = []
	for worker in workers_to_check:
		# Semaphore.try_wait() é não-bloqueante. Ele tenta "pegar" o semáforo.
		# Se conseguir (retorna true), significa que o worker terminou.
		# Se não conseguir (retorna false), o worker ainda está trabalhando.
		if worker.result_semaphore.try_wait():
			# O worker terminou, colete o resultado.
			worker.mutex.lock()
			results_from_workers.append_array(worker.output_data)
			worker.mutex.unlock()
		else:
			# O worker ainda está ocupado, adicione-o à lista para checar no próximo frame.
			still_working.append(worker)
	
	workers_to_check = still_working
	
	# Se a lista de workers para checar estiver vazia, todos terminaram.
	if workers_to_check.is_empty():
		emit_signal("ai_calculations_finished", results_from_workers)
		is_processing_wave = false


func _exit_tree():
	# Garante que as threads sejam encerradas de forma segura quando o jogo fecha
	for worker in workers:
		worker.mutex.lock()
		worker.should_exit = true
		worker.mutex.unlock()
		worker.work_semaphore.post() # Acorda a thread para que ela possa sair
	
	for thread in threads:
		thread.wait_to_finish()
	print("All AI worker threads stopped.")


# ALTERADO: Esta função agora é não-bloqueante. Ela apenas inicia o trabalho.
func request_ai_update(enemies: Array, player_pos: Vector2):
	if is_processing_wave or enemies.is_empty():
		# Ignora se ja estiver processando ou nao houver inimigos
		return

	is_processing_wave = true
	results_from_workers.clear()
	workers_to_check.clear()
	
	# Distribui a lista de inimigos entre as threads
	var batch_size = int(ceil(float(enemies.size()) / num_threads))
	
	for i in range(num_threads):
		var worker = workers[i]
		var start_index = i * batch_size
		var end_index = min(start_index + batch_size, enemies.size())
		
		if start_index >= enemies.size():
			continue # Nao ha mais inimigos para esta thread

		# Adiciona este worker à lista de workers que estamos esperando
		workers_to_check.append(worker)
		
		var batch = enemies.slice(start_index, end_index)
		
		# Adiciona a posicao do jogador a cada inimigo no lote
		for j in range(batch.size()):
			batch[j]["player_pos"] = player_pos
			
		# Envia o trabalho para a thread
		worker.mutex.lock()
		worker.input_data = batch
		worker.mutex.unlock()
		worker.work_semaphore.post() # Acorda a thread
