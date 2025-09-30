extends Area2D

@export var speed: float = 800.0
var damage: int = 10

func _process(delta: float) -> void:
	# Move a bala para frente constantemente.
	position += transform.x * speed * delta

func _on_body_entered(body: Node) -> void:
	print("entrou no body da bala")
	if body.is_in_group("enemy"):
		body.take_damage(damage)
	queue_free()

# Quando a bala sair da cena deleta a mesma
func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
