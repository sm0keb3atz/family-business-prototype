extends Resource
class_name NPCAppearanceResource

## Scans directory paths into memory at startup to prevent DirAccess stutters.
## Textures are loaded on-demand via load() to avoid VRAM exhaustion (Error -2).

@export_group("Male Paths")
@export var hairstyles_male_dir: String = "res://GAME/assets/sprites/ChracterAssets/Hairstyles/male"
@export var outfits_male_dir: String = "res://GAME/assets/sprites/ChracterAssets/Outfits/male"

@export_group("Female Paths")
@export var hairstyles_female_dir: String = "res://GAME/assets/sprites/ChracterAssets/Hairstyles/female"
@export var outfits_female_dir: String = "res://GAME/assets/sprites/ChracterAssets/Outfits/female"

@export_group("Role Paths")
@export var outfits_dealer_dir: String = "res://GAME/assets/sprites/ChracterAssets/Outfits/dealer"
@export var outfits_police_dir: String = "res://GAME/assets/sprites/ChracterAssets/Outfits/police"

@export_group("Body Paths")
@export var bodies_dir: String = "res://GAME/assets/sprites/ChracterAssets/Bodys"

# Cache: dir_path -> Array[String] (file paths)
var _path_cache: Dictionary = {}
var _is_prescanned: bool = false
## res:// path -> Texture2D — avoids load() during NPC hot realization (territory crossings).
var _texture_memo: Dictionary = {}

## Call this once at startup to scan all directory listings.
func prescan_all() -> void:
	if _is_prescanned:
		return
	_scan_dir(bodies_dir)
	_scan_dir(hairstyles_male_dir)
	_scan_dir(hairstyles_female_dir)
	_scan_dir(outfits_male_dir)
	_scan_dir(outfits_female_dir)
	_scan_dir(outfits_dealer_dir)
	_scan_dir(outfits_police_dir)
	_is_prescanned = true

func _scan_dir(dir_path: String) -> void:
	if dir_path.is_empty() or _path_cache.has(dir_path):
		return
	
	var file_paths: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("NPCAppearanceResource: Could not open directory: " + dir_path)
		_path_cache[dir_path] = file_paths
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			file_paths.append(dir_path.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()
	_path_cache[dir_path] = file_paths

func _pick_random_path(dir_path: String) -> String:
	if not _path_cache.has(dir_path):
		_scan_dir(dir_path)
	var files: Array = _path_cache.get(dir_path, [])
	if files.is_empty():
		return ""
	return str(files.pick_random())


func get_texture_cached(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_memo.has(path):
		return _texture_memo[path] as Texture2D
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_texture_memo[path] = tex
	return tex


func _get_random_texture(dir_path: String) -> Texture2D:
	var chosen_path := _pick_random_path(dir_path)
	return get_texture_cached(chosen_path)


## Pick outfit/hair/body paths once per ghost so realization only assigns textures (memoized), no DirAccess/load bursts.
func bake_for_identity(identity: NPCIdentity) -> void:
	if identity.metadata.get(&"app_baked", false):
		return
	prescan_all()
	var body_p := _pick_random_path(bodies_dir)
	var hair_p := ""
	if identity.gender == NPC.Gender.MALE:
		hair_p = _pick_random_path(hairstyles_male_dir)
	else:
		hair_p = _pick_random_path(hairstyles_female_dir)
	var outfit_p := ""
	match identity.role:
		NPC.Role.DEALER:
			outfit_p = _pick_random_path(outfits_dealer_dir)
		NPC.Role.POLICE:
			outfit_p = _pick_random_path(outfits_police_dir)
		NPC.Role.CUSTOMER:
			if identity.gender == NPC.Gender.MALE:
				outfit_p = _pick_random_path(outfits_male_dir)
			else:
				outfit_p = _pick_random_path(outfits_female_dir)
		_:
			outfit_p = _pick_random_path(outfits_male_dir)
	
	identity.metadata[&"app_body_path"] = body_p
	identity.metadata[&"app_hair_path"] = hair_p
	identity.metadata[&"app_outfit_path"] = outfit_p
	identity.metadata[&"app_backpack_visible"] = (identity.role == NPC.Role.DEALER)
	identity.metadata[&"app_baked"] = true

# --- Public helpers ---
func get_random_body() -> Texture2D:
	return _get_random_texture(bodies_dir)

func get_random_hairstyle_male() -> Texture2D:
	return _get_random_texture(hairstyles_male_dir)

func get_random_hairstyle_female() -> Texture2D:
	return _get_random_texture(hairstyles_female_dir)

func get_random_outfit_male() -> Texture2D:
	return _get_random_texture(outfits_male_dir)

func get_random_outfit_female() -> Texture2D:
	return _get_random_texture(outfits_female_dir)

func get_random_outfit_dealer() -> Texture2D:
	return _get_random_texture(outfits_dealer_dir)

func get_random_outfit_police() -> Texture2D:
	return _get_random_texture(outfits_police_dir)
