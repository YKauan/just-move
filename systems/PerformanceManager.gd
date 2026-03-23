# PerformanceManager.gd -Autoload
extends Node

@export var multithreading_enabled: bool = true

# Funcao para envelopar as tarefas do WorkerThreadPool
func execute_task(task_callable: Callable):
	if multithreading_enabled:
		# Simulacao em multithread
		WorkerThreadPool.add_task(task_callable)
	else:
		# Simulacao trhead unica
		task_callable.call()
