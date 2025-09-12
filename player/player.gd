# player/player.gd
extends CharacterBody2D

var _state_machine
var _is_attacking: bool = false

# Pegando o Input
var input: Vector2 = Vector2.ZERO

# --- Sinais ---
signal health_updated(current_health)
signal stamina_updated(current_stamina, max_stamina)
signal died

# --- Variáveis de Movimento e Atributos ---
@export_category("Variables")
@export var speed: float = 64.0
@export var max_health: int = 200
@export var _acceleration: float = 0.4
@export var _friction: float = 0.8
var current_health: int
var is_dead: bool = false

# --- Variáveis de Dash e Estamina ---
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var max_stamina: float = 100.0
var current_stamina: float
@export var dash_cost: float = 35.0
@export var stamina_regen: float = 20.0

# --- Variáveis de Combate e Cura ---
var is_dashing: bool = false
var in_combat: bool = false
var health_regen_rate: float = 5.0
@export var melee_damage: float = 30.0

# --- Variáveis da Arma de Fogo ---
var bullet_scene: PackedScene = preload("res://player/bullet.tscn")
@onready var fire_rate_timer: Timer = $FireRateTimer

# --- Referências aos novos nós ---
@onready var dash_timer = $DashTimer
@onready var out_of_combat_timer = $OutOfCombatTimer
@onready var melee_hitbox = $MeleeHitbox
@onready var melee_collision_shape = $MeleeHitbox/CollisionShape2D

@export_category("Objects")
@export var _attack_time: Timer = null
@export var _animation_tree: AnimationTree = null

func _ready() -> void:
	_state_machine = _animation_tree["parameters/playback"]
	
	add_to_group("player") #
	current_health = max_health #
	current_stamina = max_stamina
	
	emit_signal("health_updated", current_health) #
	emit_signal("stamina_updated", current_stamina, max_stamina)
	
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	out_of_combat_timer.timeout.connect(_on_out_of_combat_timer_timeout)
	melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)


func _character_movement() -> void:
	var _direction: Vector2 = Vector2(
		Input.get_axis("move_left","move_right"),
		Input.get_axis("move_up","move_down")
	)
	
	if _direction != Vector2.ZERO:
		_animation_tree["parameters/Idle/blend_position"]  = _direction
		_animation_tree["parameters/Walk/blend_position"] = _direction
		_animation_tree["parameters/Attack/blend_position"] = _direction
		
		velocity.x = lerp(velocity.x, _direction.normalized().x * speed, _acceleration)
		velocity.y = lerp(velocity.y, _direction.normalized().y * speed, _acceleration)
		return
		
	velocity.x = lerp(velocity.x, _direction.normalized().x * speed, _friction)
	velocity.y = lerp(velocity.y, _direction.normalized().y * speed, _friction)

func _attack() -> void:
	if Input.is_action_pressed("attack_melee") and not _is_attacking:
		set_physics_process(false)
		_attack_time.start()
		_is_attacking = true
		
func _animate() -> void:
	if _is_attacking:
		_state_machine.travel("Attack")
		return
	if velocity.length() > 2:
		_state_machine.travel("Walk")
		return
		
	_state_machine.travel("Idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if is_dashing:
		return

	# --- Regeneração de Estamina e Vida ---
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + stamina_regen * delta, max_stamina)
		emit_signal("stamina_updated", current_stamina, max_stamina)

	if not in_combat and current_health < max_health:
		current_health = min(current_health + health_regen_rate * delta, max_health)
		emit_signal("health_updated", current_health)

	# --- CORREÇÃO: Inputs agora são verificados aqui ---
	handle_inputs()
	
	# Processa movimento, rotação e aplica com move_and_slide
	_character_movement()
	_attack()
	_animate()
	move_and_slide() #

# --- NOVA FUNÇÃO PARA ORGANIZAR OS INPUTS ---
func handle_inputs():
	# Ação de atirar (botão direito). is_action_pressed permite segurar para atirar.
	if Input.is_action_pressed("fire") and fire_rate_timer.is_stopped(): #
		shoot()
	
	# Ação de ataque melee (botão esquerdo). is_action_just_pressed para um único ataque por clique.
	if Input.is_action_just_pressed("attack_melee"):
		perform_melee_attack()
		
	# Ação de Dash (Shift).
	if Input.is_action_just_pressed("dash") and current_stamina >= dash_cost and not is_dashing:
		perform_dash()

# --- A FUNÇÃO _unhandled_input FOI REMOVIDA, POIS A LÓGICA MUDOU PARA _physics_process ---
func shoot() -> void:
	fire_rate_timer.start() #
	var bullet = bullet_scene.instantiate() as Node2D #
	get_tree().get_root().add_child(bullet) #
	bullet.global_position = $GunPivot.global_position #
	bullet.rotation = self.rotation #

func perform_dash() -> void:
	var input_direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_direction == Vector2.ZERO:
		return
		
	is_dashing = true
	current_stamina -= dash_cost
	emit_signal("stamina_updated", current_stamina, max_stamina)
	
	velocity = input_direction.normalized() * dash_speed
	move_and_slide()
	
	dash_timer.start(dash_duration)

func perform_melee_attack() -> void:
	melee_collision_shape.disabled = false
	await get_tree().create_timer(0.2).timeout
	melee_collision_shape.disabled = true

func take_damage(amount: int) -> void:
	if is_dead: #
		return #

	current_health -= amount #
	emit_signal("health_updated", current_health) #
	
	in_combat = true
	out_of_combat_timer.start(5.0)
	
	if current_health <= 0 and not is_dead: #
		is_dead = true #
		$CollisionShape2D.disabled = true #
		set_physics_process(false) #
		emit_signal("died") #

func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = min(current_health + amount, max_health)
	emit_signal("health_updated", current_health)

func apply_upgrade(type: String, value: float) -> void:
	if type == "max_health":
		max_health += value
		current_health += value
		emit_signal("health_updated", current_health)
	elif type == "move_speed":
		speed += value
	elif type == "stamina_regen":
		stamina_regen += value

func _on_dash_timer_timeout():
	is_dashing = false
	velocity = Vector2.ZERO

func _on_out_of_combat_timer_timeout():
	in_combat = false

func _on_melee_hitbox_body_entered(body):
	if body.is_in_group("enemy"):
		body.take_damage(melee_damage)

func _on_melee_attack_timer_timeout() -> void:
	set_physics_process(true)
	_is_attacking = false
