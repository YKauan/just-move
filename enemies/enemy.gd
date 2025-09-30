extends CharacterBody2D

var _state_machine

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

# Carrega a cena do coletavel de vida
var health_pack_scene = preload("res://collectibles/HealthPack.tscn")

var player: CharacterBody2D = null
var is_invincible_event: bool = false
var is_dying: bool = false
var can_attack: bool = true
var _is_attacking: bool = false

func _ready() -> void:
	add_to_group("enemy")
	
	if _animation_tree:
		_state_machine = _animation_tree["parameters/playback"]
	else:
		printerr("Erro: _animation_tree nao foi configurada no inimigo!")

func _physics_process(_delta: float) -> void:
	# Se estiver morrendo para o inimigo
	if is_dying:
		velocity = Vector2.ZERO
		_animate()
		move_and_slide()
		return

	player = get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		_enemy_movement(player.global_position)
		_enemy_attack_logic(player)
	else:
		velocity = Vector2.ZERO
	
	_animate()
	move_and_slide()

# Movimentacao do Inimigo
func _enemy_movement(target_position: Vector2) -> void:
	var direction = (target_position - global_position).normalized()
	velocity = direction * speed
	
	# Atualiza os parametros de blend da AnimationTree com a direcao
	if _animation_tree:
		_animation_tree["parameters/idle/blend_position"] = direction
		_animation_tree["parameters/walk/blend_position"] = direction
		_animation_tree["parameters/death/blend_position"] = direction
		_animation_tree["parameters/attack/blend_position"] = direction

# Logica de ataque
func _enemy_attack_logic(target: CharacterBody2D) -> void:
	# Verifica colisao para ataque
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		
		if not collision:
			continue
		
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player") and can_attack:
			target.take_damage(damage)
			can_attack = false
			attack_cooldown_timer.start(attack_cooldown)
			_is_attacking = true 
			get_tree().create_timer(0.3).timeout.connect(func(): _is_attacking = false)

# funcao responsavel por atualizar as animacoes do inimigo
func _animate() -> void:
	if not _state_machine:
		return
		
	if _is_attacking:
		_state_machine.travel("attack")
		return
	if velocity.length() > 2:
		_state_machine.travel("walk")
		return
		
	_state_machine.travel("idle")

# Funcao para receber dano
func take_damage(amount: int) -> void:
	print("inimigo entrou para tomar dano")
	if is_dying:
		return

	health -= amount
	print(health)
	if health <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

# Funcao de morte
func die() -> void:
	emit_signal("died")
	_state_machine.travel("death")
	if randf() < dorpChance:
		var pack = health_pack_scene.instantiate()
		var world_manager_node = get_tree().get_first_node_in_group("world_manager")
		if world_manager_node:
			world_manager_node.add_child(pack)
			pack.global_position = self.global_position
		
	queue_free()

# Funcao do cooldown do timer de attack
func _on_attack_cooldown_timer_timeout() -> void:
	can_attack = true


func set_invincible_status(status: bool) -> void:
	is_invincible_event = status
	print("Enemy invincible status set to: ", status)
	
