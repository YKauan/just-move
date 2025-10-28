extends CharacterBody2D

var _state_machine

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

# Carrega a cena do coletavel de vida
var health_pack_scene = preload("res://collectibles/HealthPack.tscn")

var player: CharacterBody2D = null
var is_invincible_event: bool = false
var is_dying: bool = false
var can_attack: bool = true
var _is_attacking: bool = false

# --- NOVA VARIÁVEL ---
# O World vai definir esta direção com base nos cálculos da thread de IA.
# O inimigo se torna um "fantoche" que apenas segue a direção recebida.
var movement_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemy")
	
	if _animation_tree:
		_state_machine = _animation_tree["parameters/playback"]
	else:
		printerr("Erro: _animation_tree nao foi configurada no inimigo!")

func _physics_process(_delta: float) -> void:
	# Se estiver morrendo, para o inimigo
	if is_dying:
		velocity = Vector2.ZERO
		_animate()
		move_and_slide()
		return

	# A lógica de encontrar o player foi movida para o World.
	# O inimigo agora só precisa executar as ordens de movimento e ataque.
	
	# Chama as funções de movimento, ataque e animação
	_enemy_movement()
	_enemy_attack_logic()
	_animate()
	
	move_and_slide()


# ALTERADO: A função de movimento agora usa a variável 'movement_direction'
func _enemy_movement() -> void:
	# O inimigo não calcula mais a direção. Ele apenas usa a direção
	# que foi definida pelo serviço de IA (através do world.gd).
	velocity = movement_direction * speed
	
	# Usa a direção (normalizada se não for zero) para a animação.
	var blend_direction = movement_direction if movement_direction != Vector2.ZERO else Vector2.DOWN
	
	# Atualiza os parametros de blend da AnimationTree
	if _animation_tree:
		_animation_tree["parameters/idle/blend_position"] = blend_direction
		_animation_tree["parameters/walk/blend_position"] = blend_direction
		_animation_tree["parameters/death/blend_position"] = blend_direction
		_animation_tree["parameters/attack/blend_position"] = blend_direction


# Logica de ataque (pouca mudança aqui, ainda baseada em contato)
func _enemy_attack_logic() -> void:
	# Verifica colisao para ataque
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

# --- NOVA FUNÇÃO ---
# Esta é a função que o world.gd estava tentando chamar.
# Ela permite que o serviço de IA defina para onde este inimigo deve se mover.
func set_movement_direction(direction: Vector2):
	movement_direction = direction

# Funcao para receber dano
func take_damage(amount: int) -> void:
	if is_dying or is_invincible_event:
		return

	health -= amount
	if health <= 0 and not is_dying:
		is_dying = true
		call_deferred("die")

# Funcao de morte
func die() -> void:
	emit_signal("died")
	if _state_machine:
		_state_machine.travel("death")
	
	# Um pequeno delay para a animação de morte tocar antes de desaparecer
	await get_tree().create_timer(0.5).timeout 
	
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
