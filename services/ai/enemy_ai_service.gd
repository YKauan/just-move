# services/ai/enemy_ai_service.gd
extends Node

signal ai_calculations_finished(results)

var num_threads: int = 2 # Número de threads na pool

var threads: Array[Thread] = []
var workers: Array[RefCounted] = []
var nav_grid: NavigationGrid	

var is_processing: bool = false
var results_from_workers: Array = []
var workers_to_check: Array = [] # Lista de workers que estão trabalhando

func _ready():
	print("Enemy AI Service waiting for initialization...")

func initialize_threads(thread_count: int):
	num_threads = thread_count
	
	# Limpa listas caso seja chamado novamente (segurança)
	threads.clear()
	workers.clear()
	
	# Inicia a thread pool
	for i in range(num_threads):
		var worker = preload("res://services/ai/ai_worker.gd").new()
		var thread = Thread.new()
		
		worker.mutex = Mutex.new()
		worker.work_semaphore = Semaphore.new()
		worker.result_semaphore = Semaphore.new()
		
		# Se o nav_grid já foi configurado antes, passa para o worker
		if nav_grid:
			worker.nav_grid = nav_grid
		
		thread.start(Callable(worker, "work_loop"))
		
		threads.append(thread)
		workers.append(worker)
	
	print("Enemy AI Service initialized with %d threads." % num_threads)

func setup(_nav_grid: NavigationGrid):
	nav_grid = _nav_grid
	# Passa o grid para todos os workers existentes
	for worker in workers:
		worker.nav_grid = nav_grid

# Função _process verifica os resultados sem bloquear o jogo
func _process(_delta):
	if workers_to_check.is_empty():
		return

	var still_working = []
	for worker in workers_to_check:
		# .try_wait() é não-bloqueante. Tenta pegar o semáforo.
		# Se conseguir (true), o worker terminou.
		if worker.result_semaphore.try_wait():
			worker.mutex.lock()
			results_from_workers.append_array(worker.output_data)
			worker.mutex.unlock()
		else:
			# O worker ainda está ocupado, verifica no próximo frame
			still_working.append(worker)
	
	workers_to_check = still_working
	
	# Se a lista de verificação está vazia, todos terminaram.
	if workers_to_check.is_empty():
		emit_signal("ai_calculations_finished", results_from_workers)
		is_processing = false

# Garante que as threads fechem de forma segura
func _exit_tree():
	for worker in workers:
		worker.mutex.lock()
		worker.should_exit = true
		worker.mutex.unlock()
		worker.work_semaphore.post() # Acorda a thread para que ela possa sair
	
	for thread in threads:
		thread.wait_to_finish()
	print("All AI worker threads stopped.")

# Função chamada pelo World para iniciar o trabalho
func request_ai_update(enemies: Array, player_pos: Vector2):
	if is_processing or enemies.is_empty():
		return

	is_processing = true
	results_from_workers.clear()
	workers_to_check.clear()
	
	var batch_size = int(ceil(float(enemies.size()) / num_threads))
	
	for i in range(num_threads):
		var worker = workers[i]
		var start_index = i * batch_size
		var end_index = min(start_index + batch_size, enemies.size())
		
		if start_index >= enemies.size():
			continue 

		workers_to_check.append(worker)
		var batch = enemies.slice(start_index, end_index)
		
		for j in range(batch.size()):
			batch[j]["player_pos"] = player_pos
			
		worker.mutex.lock()
		worker.input_data = batch
		worker.mutex.unlock()
		worker.work_semaphore.post() # Acorda a thread

# Funcao usada na game_ui para ver as threads ocupadas
func get_busy_thread_count() -> int:
	return workers_to_check.size()
