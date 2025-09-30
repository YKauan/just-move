extends CharacterBody2D

var _state_machine

# Sinais
signal health_updated(current_health)
signal stamina_updated(current_stamina, max_stamina)
signal died

# Variaveis do player
@export_category("Variables Player")
@export var speed: float = 64.0
@export var max_health: float = 200.0
@export var _acceleration: float = 0.4
@export var _friction: float = 0.8
var current_health: float
var is_dead: bool = false

# Variaveis de estamina 
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 20.0 # Por segundo
var current_stamina: float

# Variaveis de combate e cura
@export var melee_damage: float = 500.0

var in_combat: bool = false
var health_regen_rate: float = 5.0

# Variaveis da arma de fogo
var bullet_scene: PackedScene = preload("res://player/bullet.tscn")
@onready var fire_rate_timer: Timer = $FireRateTimer

@onready var out_of_combat_timer = $OutOfCombatTimer
@onready var melee_hitbox = $MeleeHitbox
@onready var melee_collision_shape = $MeleeHitbox/CollisionShape2D

@export_category("Objects")
@export var _attack_time: Timer = null 
@export var _animation_tree: AnimationTree = null

# Variaveis controle dos eventos
var input_modifier: String = "none"
var move_speed_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var can_shoot_event: bool = true
var can_melee_event: bool = true

# Criando vetor de input
var input: Vector2 = Vector2.ZERO
var _is_attacking: bool = false

func _ready() -> void:
	_state_machine = _animation_tree["parameters/playback"]

	add_to_group("player")
	current_health = max_health
	current_stamina = max_stamina

	emit_signal("health_updated", current_health)
	emit_signal("stamina_updated", current_stamina, max_stamina)

	out_of_combat_timer.timeout.connect(_on_out_of_combat_timer_timeout)

# Funcao que lida com o movimento do personagem
func _character_movement() -> void:
	var _direction: Vector2 = Vector2(
		Input.get_axis("move_left","move_right"),
		Input.get_axis("move_up","move_down")
	)
	
	# Aplica evento de inverter controles caso esteja aplicado
	if input_modifier == "invert_horizontal":
		_direction.x *= -1
	elif input_modifier == "invert_vertical":
		_direction.y *= -1
	
	# Se o player nao estiver parado
	if _direction != Vector2.ZERO:
		_animation_tree["parameters/Idle/blend_position"] = _direction
		_animation_tree["parameters/Walk/blend_position"] = _direction
		_animation_tree["parameters/Attack/blend_position"] = _direction

		velocity.x = lerp(velocity.x, _direction.normalized().x * (speed * move_speed_multiplier), _acceleration)
		velocity.y = lerp(velocity.y, _direction.normalized().y * (speed * move_speed_multiplier), _acceleration)
		return
		
	velocity.x = lerp(velocity.x, 0.0, _friction)
	velocity.y = lerp(velocity.y, 0.0, _friction)

# Funcao que lida com os ataques do player
func _attack() -> void:
	if Input.is_action_pressed("attack_melee") and not _is_attacking and can_melee_event: # NOVO: Adicionado can_melee_event
		# Pausa o physics para executar a animacao de attack
		set_physics_process(false)
		_attack_time.start()
		_is_attacking = true

# funcao responsavel por atualizar as animacoes do player
func _animate() -> void:
	if _is_attacking:
		_state_machine.travel("Attack")
		return
	if velocity.length() > 2:
		_state_machine.travel("Walk")
		return
		
	_state_machine.travel("Idle")

# funcao padrao que lida com a fisica
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Regenera estamina e vida
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
		emit_signal("stamina_updated", current_stamina, max_stamina)

	if not in_combat and current_health < max_health:
		current_health = min(current_health + health_regen_rate * delta, max_health)
		emit_signal("health_updated", current_health)

	handle_inputs()
	
	# Processa movimento, ataque, animacao e aplica com move_and_slide
	_character_movement()
	_attack()
	_animate()
	move_and_slide()

# Funcao que lida com os inputs 
func handle_inputs():
	# acao de atirar
	if Input.is_action_pressed("fire") and fire_rate_timer.is_stopped() and can_shoot_event: # NOVO: Adicionado can_shoot_event
		shoot()
	
	# acao do ataque melee
	if Input.is_action_just_pressed("attack_melee") and can_melee_event: # NOVO: Adicionado can_melee_event
		perform_melee_attack()
		
# Funcao que lida com o disparo
func shoot() -> void:
	fire_rate_timer.start()
	var bullet = bullet_scene.instantiate() as Node2D
	get_tree().get_root().add_child(bullet)
	bullet.global_position = $GunPivot.global_position
	bullet.rotation = self.rotation

# Executa o ataque melee
func perform_melee_attack() -> void:
	melee_collision_shape.disabled = false
	await get_tree().create_timer(0.1).timeout
	melee_collision_shape.disabled = true

# Funcao para lidar com o dano ao personagem
func take_damage(amount: int) -> void:
	if is_dead:
		return

	var final_damage = amount * damage_taken_multiplier
	current_health -= final_damage
	emit_signal("health_updated", current_health)
	
	in_combat = true
	out_of_combat_timer.start(5.0)
	
	if current_health <= 0 and not is_dead:
		is_dead = true
		$CollisionShape2D.disabled = true 
		set_physics_process(false)
		velocity = Vector2.ZERO
		emit_signal("died")

# Funcao que lida com a cura do player
func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
	emit_signal("health_updated", current_health)

# Funcao que aplica o upgrade ao player
func apply_upgrade(type: String, value: float) -> void:
	match type:
		"max_health":
			max_health += value
			current_health = min(current_health + value, max_health) # Cura ao aumentar vida máxima
			emit_signal("health_updated", current_health)
		"move_speed":
			speed += value
		"stamina_regen":
			stamina_regen += value
		_ :
			printerr("Tipo de upgrade desconhecido: ", type)

# Funcao que indica se o player esta em combate 
func _on_out_of_combat_timer_timeout():
	in_combat = false

# Funcao de ataque melee
func _on_melee_hitbox_body_entered(body):
	print("player entrou na area de attack")
	if body.is_in_group("enemy"):
		body.take_damage(melee_damage)

# Funcao do timer do melee ataque
func _on_melee_attack_timer_timeout() -> void:
	set_physics_process(true)
	_is_attacking = false

# ==============Funcoes de Eventos Globais===================#

# altera o input
func set_input_modifier(modifier: String) -> void:
	input_modifier = modifier
	print("Player input modifier set to: ", modifier)

# altera o move speed
func set_move_speed_multiplier(multiplier: float) -> void:
	move_speed_multiplier = multiplier
	print("Player move speed multiplier set to: ", multiplier)

# reseta o move speed
func reset_move_speed_multiplier() -> void:
	move_speed_multiplier = 1.0
	print("Player move speed multiplier reset.")

# atualiza o multiplicador de dano
func set_damage_taken_multiplier(multiplier: float) -> void:
	damage_taken_multiplier = multiplier
	print("Player damage taken multiplier set to: ", multiplier)

# Reseta o multiplicador de dano
func reset_damage_taken_multiplier() -> void:
	damage_taken_multiplier = 1.0
	print("Player damage taken multiplier reset.")

# funcao para atualizar se o player pode atirar
func set_can_shoot(status: bool) -> void:
	can_shoot_event = status
	print("Player can shoot set to: ", status)

# funcao para atualizar se o player pode dar o ataque melee
func set_can_melee(status: bool) -> void:
	can_melee_event = status
	print("Player can melee set to: ", status)
