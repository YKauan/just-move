extends Node

signal ai_calculations_finished(results)
@export_category("Benchmark TCC")
@export var benchmark_mode: bool = false

var num_threads: int = 2 # Numero de threads na pool

var threads: Array[Thread] = []
var workers: Array[RefCounted] = []
var nav_grid: NavigationGrid	

var is_process: bool = false
var results_from_workers: Array = []
var workers_to_check: Array = [] # Lista de workers que estao trabalhando

func _ready():
	print("Enemy AI Service aguardando a inicializacao.. .")

# Funcao que inicializa as threads
func initialize_threads(thread_count: int):
	num_threads = thread_count
	threads.clear()
	workers.clear()
	
	for i in range(num_threads):
		var worker = preload("res://services/ai/ai_worker.gd").new()
		var thread = Thread.new()
		
		worker.mutex = Mutex.new()
		worker.work_semaphore = Semaphore.new()
		worker.result_semaphore = Semaphore.new()
		
		thread.start(Callable(worker, "work_loop"))
		threads.append(thread)
		workers.append(worker)
	
	print("Enemy AI Service inicializado com %d threads." % num_threads)

# Funcao _process verifica os resultados sem bloquear o jogo
func _process(_delta):
	if workers_to_check.is_empty():
		return

	var still_working = []
	for worker in workers_to_check:
		# Tenta pegar o semaforo se conseguir o worker finalizou
		if worker.result_semaphore.try_wait():
			worker.mutex.lock()
			results_from_workers.append_array(worker.output_data)
			worker.mutex.unlock()
		else:
			# O worker ainda esta ocupado verifica o proximo frame
			still_working.append(worker)
	
	workers_to_check = still_working
	
	# Se vazio todos terminaram
	if workers_to_check.is_empty():
		emit_signal("ai_calculations_finished", results_from_workers)
		is_process = false

# Garante que as threads fechem de forma segura
func _exit_tree():
	for worker in workers:
		worker.mutex.lock()
		worker.should_exit = true
		worker.mutex.unlock()
		worker.work_semaphore.post()
	
	for thread in threads:
		thread.wait_to_finish()
	print("Todos worker threads pararam.")

# Funcao chamada pelo World para iniciar o work
func request_ai_update(enemies: Array, player_pos: Vector2):
	if is_process or enemies.is_empty():
		return

	if benchmark_mode:
		_run_single_thread_benchmark(enemies, player_pos)
	else:
		_run_multithread_processing(enemies, player_pos)

# Funcao a executar em multi thread
func _run_multithread_processing(enemies: Array, player_pos: Vector2):
	if is_process or enemies.is_empty():
		return

	is_process = true
	results_from_workers.clear()
	workers_to_check.clear()
	
	# Coleta todas as posicoes uma unica vez para passar aos workers
	var all_positions = []
	for e in enemies:
		all_positions.append(e["pos"])
	
	var batch_size = int(ceil(float(enemies.size()) / num_threads))
	
	for i in range(num_threads):
		var worker = workers[i]
		var start_index = i * batch_size
		var end_index = min(start_index + batch_size, enemies.size())
		
		if start_index >= enemies.size(): continue 

		var batch = enemies.slice(start_index, end_index)
		for item in batch:
			item["player_pos"] = player_pos
			
		worker.mutex.lock()
		worker.input_data = batch
		worker.all_enemy_positions = all_positions
		worker.mutex.unlock()
		
		workers_to_check.append(worker)
		worker.work_semaphore.post()

# Funcao para executar em thread unica
func _run_single_thread_benchmark(enemies: Array, player_pos: Vector2):
	is_process = true
	var sync_results = []
	
	var all_positions = []
	for e in enemies:
		all_positions.append(e["pos"])
	
	# 2. Obter o provedor de lógica
	var single_worker
	if not workers.is_empty():
		single_worker = workers[0]
	else:
		single_worker = preload("res://services/ai/ai_worker.gd").new()
	
	# Processa cada inimigo sequencialmente 
	for enemy in enemies:
		enemy["player_pos"] = player_pos
		# Passa o inimigo atual e a lista de todos os outros para a separacao
		sync_results.append(single_worker.process_single_enemy(enemy, all_positions))
	
	ai_calculations_finished.emit(sync_results)
	is_process = false

# Funcao usada na game_ui para ver as threads ocupadas
func get_busy_thread_count() -> int:
	return workers_to_check.size()
