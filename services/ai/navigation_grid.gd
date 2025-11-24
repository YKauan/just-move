class_name NavigationGrid
extends RefCounted

var astar: AStarGrid2D
var cell_size: Vector2 = Vector2(32, 32)
var grid_rect: Rect2i

func setup_grid(world_rect: Rect2i, obstacles: Array[Node2D]):
	grid_rect = world_rect # Guardamos para debug e verificação
	
	astar = AStarGrid2D.new()
	astar.region = world_rect
	astar.cell_size = cell_size
	
	# Configuração para permitir diagonais e movimento suave
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	
	# Mapeia obstáculos
	for obs in obstacles:
		if is_instance_valid(obs):
			var grid_pos = get_grid_position(obs.global_position)
			if world_rect.has_point(grid_pos):
				astar.set_point_solid(grid_pos, true)

func get_grid_position(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / cell_size.x), floor(world_pos.y / cell_size.y))

func get_next_path_position(from_world: Vector2, to_world: Vector2) -> Vector2:
	var direct_direction = (to_world - from_world).normalized()
	
	# 1. Validação Básica: Se estiver muito perto, não use A* (evita tremedeira)
	if from_world.distance_to(to_world) < cell_size.x:
		return direct_direction

	var from_id = get_grid_position(from_world)
	var to_id = get_grid_position(to_world)
	
	# 2. Verifica Limites: Se estiver fora do Grid, use vetor direto
	if not astar.region.has_point(from_id) or not astar.region.has_point(to_id):
		return direct_direction

	# 3. Calcula Caminho A*
	var path = astar.get_id_path(from_id, to_id)
	
	# 4. Verifica Caminho: Se não achou caminho ou é muito curto
	if path.size() <= 1:
		return direct_direction
	
	# 5. Sucesso: Pega o centro do próximo tile
	var next_cell_grid_pos = path[1]
	var next_cell_world_pos = (Vector2(next_cell_grid_pos) * cell_size) + (cell_size / 2)
	
	var astar_direction = (next_cell_world_pos - from_world).normalized()
	
	# 6. Proteção Final: Se o A* retornar zero (erro de cálculo), use direto
	if astar_direction == Vector2.ZERO:
		return direct_direction
		
	return astar_direction
