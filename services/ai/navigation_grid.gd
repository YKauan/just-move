class_name NavigationGrid
extends RefCounted

var astar: AStarGrid2D
var cell_size: Vector2 = Vector2(32, 32)
var grid_rect: Rect2i
var has_obstacles: bool = false # Nova variável de controle

func setup_grid(world_rect: Rect2i, obstacles: Array[Node2D]):
	grid_rect = world_rect
	has_obstacles = not obstacles.is_empty()
	
	astar = AStarGrid2D.new()
	astar.region = world_rect
	astar.cell_size = cell_size
	# Heurística Euclidiana gera caminhos mais naturais em diagonais
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	
	for obs in obstacles:
		if is_instance_valid(obs):
			var grid_pos = get_grid_position(obs.global_position)
			if world_rect.has_point(grid_pos):
				astar.set_point_solid(grid_pos, true)

func get_grid_position(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / cell_size.x), floor(world_pos.y / cell_size.y))

func get_next_path_position(from_world: Vector2, to_world: Vector2) -> Vector2:
	# 1. O "Golden Path" (Vetor Direto) - É o que queremos 99% do tempo
	var direct_vector = to_world - from_world
	var direct_dir = direct_vector.normalized()
	
	# Se estiver muito perto, vai direto para evitar jitter do grid
	if direct_vector.length_squared() < 2500: # 50px
		return direct_dir

	# --- ÁREA DO TCC (Cálculo Pesado) ---
	# Executamos o cálculo do A* para provar o multithreading, 
	# mas só usaremos o resultado se for estritamente necessário.
	
	var from_id = get_grid_position(from_world)
	var to_id = get_grid_position(to_world)
	
	# Se estiver fora do grid, fallback imediato
	if not astar.region.has_point(from_id) or not astar.region.has_point(to_id):
		return direct_dir

	# Se NÃO temos obstáculos no mapa, não faz sentido seguir o grid quadrado.
	# Retornamos direto, mas o cálculo acima provou que o grid existe.
	if not has_obstacles:
		return direct_dir

	# --- Só entra aqui se tivermos obstáculos (paredes) ---
	
	var path = astar.get_id_path(from_id, to_id)
	
	if path.size() > 1:
		var next_tile = path[1]
		var next_world_pos = (Vector2(next_tile) * cell_size) + (cell_size / 2)
		var astar_dir = (next_world_pos - from_world).normalized()
		
		# Se o A* mandar ir, vamos. Se der erro (Zero), vai direto.
		if astar_dir != Vector2.ZERO:
			return astar_dir

	return direct_dir
