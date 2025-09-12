extends Area2D

var heal_amount: int = 25

func _on_body_entered(body: Node) -> void:
	# Verifica se quem entrou na área foi o jogador
	if body.is_in_group("player"):
		# Chama a função de cura que criamos no player
		body.heal(heal_amount)
		# Destrói o coletável
		queue_free()
