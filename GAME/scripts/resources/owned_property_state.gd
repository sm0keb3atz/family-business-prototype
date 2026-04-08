class_name OwnedPropertyState extends Resource

@export var property_data: PropertyResource
@export var stash: StashInventory

# Set up the default stash based on property capacity
func initialize(p_data: PropertyResource) -> void:
	property_data = p_data
	stash = StashInventory.new()
	stash.capacity = p_data.stash_capacity
