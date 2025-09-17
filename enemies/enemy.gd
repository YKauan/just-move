extends CharacterBody2D

var _state_machine
var _is_attacking: bool = false # Mantido para compatibilidade com o _animate() original

# Sinais
signal died

@export_category("Variables")
@export var speed: float = 34.0
@export var health: int = 30
@export var damage: int = 10
@export var dorpChance: float = 0.2
@export var attack_cooldown: float = 1.0

@export_category("Objects")
@export var _animation_tree: AnimationTree = null

@onready var attack_cooldown_timer = $AttackCooldownTimer

var player: CharacterBody2D = null

# Carrega a cena do coletavel de vida
var health_pack_scene = preload("res://collectibles/HealthPack.tscn")

var is_invincible_event: bool = false

# Flag para evitar que a funcao de morte seja chamada varias vezes
var is_dying: bool = false

# Flag que indica se o inimigo pode atacar
var can_attack: bool = true

func _ready() -> void:
	if _animation_tree: # Verificação de segurança
		_state_machine = _animation_tree["parameters/playback"]
	else:
		printerr("Erro: _animation_tree não foi configurada no inimigo!")

	add_to_group("enemy")
	# attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)

func _physics_process(_delta: float) -> void:
	# Se estiver morrendo, não faz nada além de parar
	if is_dying:
		velocity = Vector2.ZERO
		_animate() # Ainda anima, por exemplo, para um estado de morte, se houver
		move_and_slide()
		return

	player = get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		_enemy_movement(player.global_position) # Chamada da nova função de movimento
		_enemy_attack_logic(player) # Chamada da nova função de ataque
	else:
		# Se não encontrar o jogador, fica parado
		velocity = Vector2.ZERO
	
	_animate() # Atualiza as animações
	move_and_slide()

# NOVA FUNÇÃO: Lida com o movimento do inimigo em direção a um alvo
func _enemy_movement(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	velocity = direction * speed
	
	# Atualiza os parâmetros de blend da AnimationTree com a direção
	if _animation_tree:
		_animation_tree["parameters/idle/blend_position"] = direction
		_animation_tree["parameters/walk/blend_position"] = direction
		# Se a animação de ataque tiver blend_position, também atualize aqui
		_animation_tree["parameters/attack/blend_position"] = direction


# NOVA FUNÇÃO: Lida com a lógica de ataque do inimigo
func _enemy_attack_logic(target: CharacterBody2D) -> void:
	# Verifica colisão para ataque (lógica original)
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if not collision:
			continue
		
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player") and can_attack:
			target.take_damage(damage) # O dano é aplicado
			can_attack = false # Inicia o cooldown
			attack_cooldown_timer.start(attack_cooldown)
			_is_attacking = true # Ativa a flag para a animação de ataque
			# Este timer definirá _is_attacking como false após um curto período,
			# permitindo que a animação de ataque toque por um tempo definido.
			# Ajuste o 0.3 para a duração que você quer que a animação de ataque dure.
			get_tree().create_timer(0.3).timeout.connect(func(): _is_attacking = false)


# funcao responsavel por atualizar as animacoes do inimigo
func _animate() -> void:
	if not _state_machine: # Verificação de segurança
		return
		
	if _is_attacking:
		_state_machine.travel("attack") # Certifique-se de que "Attack" é o nome correto
		return
	if velocity.length() > 2:
		_state_machine.travel("walk") # Certifique-se de que "Walk" é o nome correto
		return
		
	_state_machine.travel("idle") # Certifique-se de que "Idle" é o nome correto

# Funcao para o inimigo receber dano
func take_damage(amount: int) -> void:
	if is_dying or is_invincible_event:
		return

	health -= amount
	if health <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

func die() -> void:
	emit_signal("died")
	
	if randf() < dorpChance:
		var pack = health_pack_scene.instantiate()
		var world_manager_node = get_tree().get_first_node_in_group("world_manager")
		if world_manager_node: # Verificação de segurança
			world_manager_node.add_child(pack)
			pack.global_position = self.global_position
		
	queue_free()


func _on_attack_cooldown_timer_timeout() -> void:
	can_attack = true
	
func set_invincible_status(status: bool) -> void:
	is_invincible_event = status
	print("Enemy invincible status set to: ", status)


func _on_timeout() -> void:
	pass # Replace with function body.
