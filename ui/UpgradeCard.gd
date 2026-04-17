extends PanelContainer

signal card_selected

# Referencias aos componentes do card
@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var title_label: Label = $VBoxContainer/VBoxContainer/TitleLabel 
@onready var description_label: Label = $VBoxContainer/VBoxContainer/DescriptionLabel
@onready var button: Button = $Button

func _ready() -> void:
	# Garante que os nos foram encontrados
	if not is_instance_valid(button):
		printerr("erro no UpgradeCard No Button nao encontrado. O clique nao funfa.")
		return

	button.pressed.connect(func():
		print("UpgradeCard Botoo interno clicado")
		emit_signal("card_selected")
	)

# Funcao para preencher o card com os dados
func update_card_data(data: Dictionary) -> void:
	# Garante que os Nos foram encontrados
	if is_instance_valid(title_label):
		title_label.text = data.get("name", "UPGRADE")
	else:
		printerr("erro no UpgradeCard, TitleLabel nao encontrado")
	# Garante que os Nos foram encontrados
	if is_instance_valid(description_label):
		description_label.text = data.get("text", "Descrição...")
	else:
		printerr("ERRO no UpgradeCard: DescriptionLabel nao encontrado")
	
	var icon_path = data.get("icon_path", "")
	if is_instance_valid(icon):
		if FileAccess.file_exists(icon_path):
			icon.texture = load(icon_path)
		else:
			icon.texture = load("res://icon.svg")
			printerr("Icone nao encontrado em: ", icon_path)
	else:
		printerr("ERRO no UpgradeCard Icon nao encontrado.")
