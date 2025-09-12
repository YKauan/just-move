extends Node

# Função para mudar para qualquer cena, garantindo que o jogo esteja despausado.
func go_to_scene(scene_path: String):
	# Garante que o jogo não esteja pausado antes de tentar mudar de cena.
	get_tree().paused = false
	
	# Muda para a cena especificada no caminho.
	get_tree().change_scene_to_file(scene_path)
