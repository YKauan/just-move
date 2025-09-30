extends Area2D

var heal_amount: int = 25

func _on_body_entered(body: Node) -> void:
	# Verifica se quem entrou na area foi o jogador
	if body.is_in_group("player"):
		# Chama a funcao de cura do player
		body.heal(heal_amount)
		queue_free()
