extends CharacterBody2D

# Sinais
signal died

@export_category("Variables")
@export var speed: float = 34.0
@export var health: int = 30
@export var damage: int = 10
@export var dorpChance: float = 0.2
@export var attack_cooldown: float = 1.0

@onready var attack_cooldown_timer = $AttackCooldownTimer

var player: CharacterBody2D = null

# Carregua a cena do coletavel de vida
var health_pack_scene = preload("res://collectibles/HealthPack.tscn") # Verifique se o caminho está correto!

# Flag para evitar que a funcao de morte seja chamada varias vezes
var is_dying: bool = false

# Flag que indica se o inimigo pode atacar
var can_attack: bool = true

func _ready() -> void:
	add_to_group("enemy")

func _physics_process(_delta: float) -> void:
	# Se estiver morrendo nao nada
	if is_dying: return 

	player = get_tree().get_first_node_in_group("player")
	
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			
			if not collision:
				continue
			
			var collider = collision.get_collider()
			
			if collider and collider.is_in_group("player") and can_attack:
				collider.take_damage(damage)
				can_attack = false
				attack_cooldown_timer.start(attack_cooldown)

# Funcao para o inimigo receber dano
func take_damage(amount: int) -> void:
	# Se o inimigo ja esta morrendo nao recebe mais dano
	if is_dying:
		return

	health -= amount
	# A condição agora também verifica se ele já não está morrendo
	if health <= 0 and not is_dying:
		# Marca que está morrendo para não entrar aqui de novo
		is_dying = true
		
		# Chama a funcao para eliminar um inimigo
		call_deferred("die")

# --- NOVA FUNÇÃO ---
func die() -> void:
	# Toda a lógica que acontecia após a vida chegar a zero foi movida para cá.
	# Como esta função foi chamada com 'call_deferred', ela só executará em um momento seguro.
	emit_signal("died")
	
	# Chance de dropar um item de cura
	if randf() < dorpChance:
		var pack = health_pack_scene.instantiate()
		get_tree().get_first_node_in_group("world_manager").add_child(pack)
		pack.global_position = self.global_position
		
	queue_free()


func _on_attack_cooldown_timer_timeout() -> void:
	can_attack = true
