extends Node

# Funcao para mudar para qualquer cena garantindo que o jogo esteja despausado
func go_to_scene(scene_path: String):
	get_tree().paused = false
	
	get_tree().change_scene_to_file(scene_path)
