extends PanelContainer

# Sinal que o card emitirá quando for clicado
signal card_selected

# --- Referências aos nós internos do card ---
# Garanta que estes caminhos correspondam EXATAMENTE à sua cena UpgradeCard.tscn
# Se os labels estiverem dentro de um VBoxContainer aninhado, o caminho deve ser como abaixo.
# Se não, remova o "VBoxContainer/" extra.
@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var title_label: Label = $VBoxContainer/VBoxContainer/TitleLabel 
@onready var description_label: Label = $VBoxContainer/VBoxContainer/DescriptionLabel
@onready var button: Button = $Button

func _ready() -> void:
	# Verificação de segurança para garantir que os nós foram encontrados
	if not is_instance_valid(button):
		printerr("ERRO CRÍTICO no UpgradeCard: Nó 'Button' não encontrado. O clique não funcionará.")
		return # Interrompe se o botão não existe

	# Conecta o clique do botão interno para emitir nosso próprio sinal
	button.pressed.connect(func():
		print("UpgradeCard: Botão interno clicado!")
		emit_signal("card_selected")
	)

# Função pública para preencher o card com dados de um dicionário (do JSON)
func update_card_data(data: Dictionary) -> void:
	# Verificações de segurança para evitar crash se um nó não for encontrado
	if is_instance_valid(title_label):
		title_label.text = data.get("name", "UPGRADE")
	else:
		printerr("ERRO no UpgradeCard: Nó 'TitleLabel' não encontrado. Verifique o caminho no script.")

	if is_instance_valid(description_label):
		description_label.text = data.get("text", "Descrição...")
	else:
		printerr("ERRO no UpgradeCard: Nó 'DescriptionLabel' não encontrado. Verifique o caminho no script.")
	
	var icon_path = data.get("icon_path", "")
	if is_instance_valid(icon):
		if FileAccess.file_exists(icon_path):
			icon.texture = load(icon_path)
		else:
			icon.texture = load("res://icon.svg") # Ícone padrão
			printerr("Ícone não encontrado em: ", icon_path)
	else:
		printerr("ERRO no UpgradeCard: Nó 'Icon' não encontrado.")
