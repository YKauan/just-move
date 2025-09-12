extends Area2D

@export var speed: float = 800.0
var damage: int = 10

func _process(delta: float) -> void:
	# Move a bala para frente constantemente.
	position += transform.x * speed * delta

func _on_body_entered(body: Node) -> void:
	# Se a bala colidir com um corpo no grupo "enemy"...
	if body.is_in_group("enemy"):
		# ...chama a função take_damage do inimigo.
		body.take_damage(damage)
	
	# Destroi a bala após a colisão.
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	# Destroi a bala se ela sair da tela.
	queue_free()
