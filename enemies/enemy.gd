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

var health_pack_scene = preload("res://collectibles/HealthPack.tscn")

var is_invincible_event: bool = false
var is_dying: bool = false
var can_attack: bool = true
var _is_attacking: bool = false

# A direcao e definida pelo EnemyAIService
var movement_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemy")
	
	if _animation_tree:
		_state_machine = _animation_tree["parameters/playback"]
	else:
		printerr("Erro _animation_tree nao foi configurada no inimigo")

func _physics_process(_delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		_animate()
		move_and_slide()
		return

	_enemy_movement()
	_enemy_attack_logic()
	_animate()
	
	move_and_slide()

# Funcao para aplicar a movimentacao do inimigo
func _enemy_movement() -> void:
	velocity = movement_direction * speed
	
	# Verifica a direcao para a animacao
	var blend_direction = movement_direction if movement_direction != Vector2.ZERO else Vector2.DOWN
	
	if _animation_tree:
		_animation_tree["parameters/idle/blend_position"] = blend_direction
		_animation_tree["parameters/walk/blend_position"] = blend_direction
		_animation_tree["parameters/death/blend_position"] = blend_direction
		_animation_tree["parameters/attack/blend_position"] = blend_direction

# Logica para os ataques dos inimigos
func _enemy_attack_logic() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if not collision:
			continue
		
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player") and can_attack:
			collider.take_damage(damage)
			can_attack = false
			attack_cooldown_timer.start(attack_cooldown)
			_is_attacking = true
			get_tree().create_timer(0.3).timeout.connect(func(): _is_attacking = false)

# Funcao para aplicar as animacoes
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

# Funcao que diz a direcao do movimento e chamada no world.gd
func set_movement_direction(direction: Vector2):
	movement_direction = direction

# Funcao para receber dano
func take_damage(amount: int):
	if is_dying or is_invincible_event:
		return
	health -= amount
	if health <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

# Funcao de morte
func die():
	emit_signal("died")
	if _state_machine:
		_state_machine.travel("death")
	
	await get_tree().create_timer(0.5).timeout 
	
	if randf() < dorpChance:
		var pack = health_pack_scene.instantiate()
		var world_manager_node = get_tree().get_first_node_in_group("world_manager")
		if world_manager_node:
			world_manager_node.add_child(pack)
			pack.global_position = self.global_position
		
	queue_free()

# Funcao do timer de finalizacao do cooldown de ataque
func _on_attack_cooldown_timer_timeout():
	can_attack = true
