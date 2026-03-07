@tool
extends BTDecorator
class_name BTDecoratorCommitWindow
## Prevents branch re-evaluation from interrupting the child task
## for a minimum duration after it first returns RUNNING.
## Once the window expires, normal BT evaluation resumes.
##
## Use on sequences inside a BTDynamicSelector to add hysteresis
## and prevent action flip-flopping ("branch thrashing").
##
## How it works with LimboAI:
## - On each tick, the base BTDecorator calls the child automatically.
## - This decorator intercepts the result: if the child is RUNNING
##   and within the commit window, it returns RUNNING even if the
##   child's condition fails (preventing the DynamicSelector from
##   switching to a different branch).
## - The commit window uses a blackboard timestamp for persistence.

@export var min_commit_seconds: float = 1.5
## Blackboard key used to store the commit deadline. Each instance
## should use a unique key if multiple commit decorators exist.
@export var commit_key: StringName = &"_commit_until"

func _generate_name() -> String:
	return "Commit Window (%ss)" % min_commit_seconds

func _enter() -> void:
	if blackboard:
		blackboard.set_var(commit_key, 0.0)

func _tick(delta: float) -> Status:
	var now: float = Time.get_ticks_msec() / 1000.0
	var commit_until: float = 0.0
	if blackboard:
		commit_until = blackboard.get_var(commit_key, 0.0)

	# If we're inside an active commit window, the child MUST keep running.
	# Even if the child's leading condition fails, return RUNNING to prevent
	# the DynamicSelector from switching branches.
	if commit_until > 0.0 and now < commit_until:
		# Child is still committed — tick normally
		var child_status: Status = get_child(0).execute(delta) if get_child_count() > 0 else FAILURE
		if child_status != RUNNING:
			# Child finished naturally — clear commit window
			if blackboard:
				blackboard.set_var(commit_key, 0.0)
			return child_status
		return RUNNING

	# Outside commit window — evaluate child normally
	var child_status: Status = get_child(0).execute(delta) if get_child_count() > 0 else FAILURE

	# Start a new commit window when child enters RUNNING
	if child_status == RUNNING:
		if blackboard:
			blackboard.set_var(commit_key, now + min_commit_seconds)

	return child_status
