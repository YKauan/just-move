extends CanvasLayer

# Referências aos labels principais da UI
@onready var health_label = $HealthLabel
@onready var stamina_label = $StaminaLabel
@onready var enemy_counter_label = $EnemyCounterLabel
@onready var pause_menu = $PauseMenu
@onready var event_message_label = $EventMessageLabel
@onready var fps_counter_label = $FPSCounterLabel

# Referências ao novo sistema de cards de upgrade
@onready var upgrade_card_container = $UpgradeCardContainer
@onready var upgrade_cards: Array[Node] = [ # Use Array[Node] para tipagem mais clara
	$UpgradeCardContainer/CardHolder/UpgradeCard1,
	$UpgradeCardContainer/CardHolder/UpgradeCard2,
	$UpgradeCardContainer/CardHolder/UpgradeCard3
]

# Variáveis de controle
var world_manager: Node = null # Inicialize como null
var current_upgrades: Array = [] # Armazena os dados dos upgrades atuais

func _ready() -> void:
	# Await para garantir que o World já esteja pronto e no grupo
	await get_tree().process_frame
	world_manager = get_tree().get_first_node_in_group("world_manager")
	
	if world_manager == null:
		printerr("ERROR: World manager not found in 'world_manager' group.")
		# Considere parar o jogo ou tomar outra ação de recuperação aqui
	
	# Esconde todos os menus e elementos de UI que não devem estar visíveis no início
	pause_menu.hide()
	upgrade_card_container.hide()
	event_message_label.hide()
	
	# Conecta o sinal personalizado 'card_selected' de cada card
	# Cada UpgradeCard (que tem o script UpgradeCard.gd) emite este sinal
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i] # 'card' é uma instância de UpgradeCard
		if card and card.has_method("update_card_data"): # Garante que é um UpgradeCard válido
			card.card_selected.connect(_on_upgrade_selected.bind(i))
		else:
			printerr("ERROR: UpgradeCard ", i, " is not a valid UpgradeCard instance or missing script.")


func _process(delta: float) -> void:
	# Atualiza o contador de FPS (para fins de depuração e TCC)
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	fps_counter_label.text = "FPS: " + str(fps)

# --- Funções para Atualizar Labels da UI ---

func update_health_label(new_health: int) -> void:
	health_label.text = "Health: %d" % new_health

func update_stamina_label(current_stamina: int, max_stamina: int) -> void:
	stamina_label.text = "Stamina: %d/%d" % [current_stamina, max_stamina]

func update_enemy_counter(count: int) -> void:
	enemy_counter_label.text = "Enemies: %d" % count

# --- Funções para Gerenciamento de Menus e Upgrades ---

func toggle_pause_menu(is_paused: bool) -> void:
	pause_menu.visible = is_paused

# Mostra a tela de upgrades e preenche os cards com os dados recebidos
func show_upgrade_screen(upgrades: Array) -> void:
	current_upgrades = upgrades
	upgrade_card_container.show()
	
	for i in range(upgrade_cards.size()):
		var card = upgrade_cards[i]
		if i < upgrades.size():
			if card and card.has_method("update_card_data"):
				card.update_card_data(upgrades[i])
				card.show()
			else:
				printerr("ERROR: Cannot update card ", i, ". Invalid instance or missing update_card_data method.")
				card.hide() # Esconde se for inválido
		else:
			# Esconde cards extras se houver menos de 3 upgrades para mostrar
			card.hide()

# Chamado quando um upgrade card é clicado
func _on_upgrade_selected(index: int) -> void:
	if world_manager and index < current_upgrades.size():
		var chosen_upgrade = current_upgrades[index]
		
		# Assume que chosen_upgrade é um Dictionary com "type" e "value"
		# (O JSON deve ter esses campos)
		var upgrade_type = chosen_upgrade.get("type", "")
		var upgrade_value = chosen_upgrade.get("value", 0.0)
		
		if upgrade_type != "":
			world_manager.apply_player_upgrade(upgrade_type, upgrade_value)
		else:
			printerr("ERROR: Upgrade type is empty for chosen upgrade at index ", index)
		
	upgrade_card_container.hide()

# --- Funções para Mensagens de Evento ---

func show_event_message(message: String) -> void:
	event_message_label.text = message
	event_message_label.show()
	# Pode adicionar um Timer para esconder a mensagem automaticamente após um tempo
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(hide_event_message)

func hide_event_message() -> void:
	event_message_label.hide()

# --- Funções dos Botões do Menu de Pausa ---

func _on_ResumeButton_pressed():
	if world_manager:
		world_manager.toggle_pause()

func _on_MainMenuButton_pressed():
	get_tree().paused = false
	# Certifique-se de que SceneManager existe e tem o método go_to_scene
	SceneManager.go_to_scene("res://main_menu/MainMenu.tscn")
