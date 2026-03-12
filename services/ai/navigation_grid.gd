class_name NavigationGrid
extends RefCounted

var astar: AStarGrid2D
var cell_size: Vector2 = Vector2(32, 32)
var grid_rect: Rect2i
var has_obstacles: bool = false

func setup_grid(world_rect: Rect2i, obstacles: Array[Node2D]):
	grid_rect = world_rect
	has_obstacles = not obstacles.is_empty()
	
	astar = AStarGrid2D.new()
	astar.region = world_rect
	astar.cell_size = cell_size
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
	var direct_vector = to_world - from_world
	var direct_dir = direct_vector.normalized()
	
	if direct_vector.length_squared() < 2500: # 50px
		return direct_dir

	# Simulando A*
	var from_id = get_grid_position(from_world)
	var to_id = get_grid_position(to_world)
	
	# Se estiver fora do grid fallback
	if not astar.region.has_point(from_id) or not astar.region.has_point(to_id):
		return direct_dir

	if not has_obstacles:
		return direct_dir
	
	# Prossegue caso tenha obstaculos
	var path = astar.get_id_path(from_id, to_id)
	
	if path.size() > 1:
		var next_tile = path[1]
		var next_world_pos = (Vector2(next_tile) * cell_size) + (cell_size / 2)
		var astar_dir = (next_world_pos - from_world).normalized()
		
		if astar_dir != Vector2.ZERO:
			return astar_dir

	return direct_dir
