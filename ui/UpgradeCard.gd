extends PanelContainer

# Sinal que o card emitirá quando for clicado
signal card_selected

# Referências aos nós internos do card
@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var title_label: Label = $VBoxContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $VBoxContainer/VBoxContainer/DescriptionLabel
@onready var button: Button = $Button

func _ready() -> void:
	# Conecta o clique do botão interno para emitir nosso próprio sinal
	button.pressed.connect(func(): emit_signal("card_selected"))

# Função pública para preencher o card com dados de um dicionário (do JSON)
func update_card_data(data: Dictionary) -> void:
	title_label.text = data.get("name", "UPGRADE")
	description_label.text = data.get("text", "Descrição...")
	
	var icon_path = data.get("icon_path", "")
	if FileAccess.file_exists(icon_path):
		icon.texture = load(icon_path)
	else:
		# Define um ícone padrão caso o caminho seja inválido ou não exista
		icon.texture = load("res://icon.svg") 
		printerr("Ícone não encontrado em: ", icon_path)
