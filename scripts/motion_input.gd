extends RefCounted
## Facing-relative quarter circles. Repeated directions and neutral are ignored;
## all three distinct directions must be entered in order within 24 frames.
const WINDOW := 0.4
var history: Array[Dictionary] = []
var last_direction: int = 5

func record(direction: int, time: float) -> void:
	if direction == last_direction:
		return
	last_direction = direction
	if direction == 5:
		return
	history.append({"direction": direction, "time": time})
	while history.size() > 10:
		history.pop_front()

func consume(time: float) -> String:
	if history.size() < 3:
		return ""
	var start := history.size() - 3
	if time - float(history[start].time) > WINDOW:
		return ""
	var sequence := [history[start].direction, history[start + 1].direction, history[start + 2].direction]
	var result := ""
	if sequence == [2, 3, 6] and last_direction == 6:
		result = "drive"
	elif sequence == [2, 1, 4] and last_direction == 4:
		result = "breaker"
	if not result.is_empty():
		history.clear()
	return result

func reset() -> void:
	history.clear()
	last_direction = 5
