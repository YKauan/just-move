# enemies/enemy.gd
extends CharacterBody2D

signal died

@export var speed: float = 34.0
@export var health: int = 30
@export var damage: int = 10

var player: CharacterBody2D = null
# NOVO: Carregue a cena do coletável aqui, se ainda não o fez.
var health_pack_scene = preload("res://collectibles/HealthPack.tscn") # Verifique se o caminho está correto!

# NOVO: Flag para evitar que a função de morte seja chamada várias vezes
var is_dying: bool = false

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if is_dying: return # Se estiver morrendo, não faz mais nada

	player = get_tree().get_first_node_in_group("player")
	
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision.get_collider().is_in_group("player"):
				collision.get_collider().take_damage(damage)

# --- FUNÇÃO ALTERADA ---
func take_damage(amount: int) -> void:
	# Se o inimigo já está morrendo, não recebe mais dano
	if is_dying:
		return

	health -= amount
	# A condição agora também verifica se ele já não está morrendo
	if health <= 0 and not is_dying:
		is_dying = true # Marca que está morrendo para não entrar aqui de novo
		# Em vez de chamar queue_free() diretamente,
		# nós adiamos a chamada da nossa nova função die()
		call_deferred("die")

# --- NOVA FUNÇÃO ---
func die() -> void:
	# Toda a lógica que acontecia após a vida chegar a zero foi movida para cá.
	# Como esta função foi chamada com 'call_deferred', ela só executará em um momento seguro.
	emit_signal("died")
	
	# Chance de dropar um item de cura
	if randf() < 0.2: # 20% de chance
		var pack = health_pack_scene.instantiate()
		get_tree().get_first_node_in_group("world_manager").add_child(pack)
		pack.global_position = self.global_position
		
	queue_free()
