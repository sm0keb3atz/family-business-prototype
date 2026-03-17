extends Resource
class_name NPCNamesResource

@export var feminine_names: Array[String] = [
	"Keisha", "Tiara", "Diamond", "Aaliyah", "Jada", "Tanisha", "Shanice", "Ebony", 
	"Latoya", "Destiny", "Raven", "Imani", "Kiara", "Makayla", "Nia", "Zoe"
]

func get_random_name() -> String:
	if feminine_names.is_empty():
		return "Baby"
	return feminine_names.pick_random()
