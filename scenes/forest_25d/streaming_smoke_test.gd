extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _added(before: Array, land: Node3D) -> int:
	var count := 0
	for key in land.chunks:
		if not before.has(key):
			count += 1
	return count


func _run() -> void:
	var land = load("res://scenes/forest_25d/landscape.gd").new()
	root.add_child(land)
	land.build()
	land.stream(Vector2.ZERO, Vector2(12, 12))
	assert(land.chunks.size() == 16)
	await process_frame
	await process_frame
	land.stream(Vector2(10, 0), Vector2(12, 12))
	var before: Array = land.chunks.keys()
	land.stream(Vector2(11, 0), Vector2(12, 12))
	assert(_added(before, land) == 1, "Moving a stream window must not build an entire chunk row in one frame")
	var same_frame: Array = land.chunks.keys()
	land.stream(Vector2(11, 0), Vector2(12, 12))
	assert(_added(same_frame, land) == 0, "Two refresh callers must share the frame's build budget")
	# Reverse before the old queue drains: stale requests must be cancelled.
	land.stream(Vector2(10, 0), Vector2(12, 12))
	for i in 8:
		await process_frame
		before = land.chunks.keys()
		land.stream(Vector2(10, 0), Vector2(12, 12))
		assert(_added(before, land) <= 1)
	assert(land.chunks.size() == 12 and land._pending_chunks.is_empty())
	for key in land.chunks:
		assert(key.x >= -1 and key.x <= 1)
	land.stream(Vector2.ZERO, Vector2(12, 12))
	for x in range(1, 65):
		await process_frame
		before = land.chunks.keys()
		land.stream(Vector2(x, 0), Vector2(12, 12))
		assert(_added(before, land) <= 1)
		for offset in [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12)]:
			var p: Vector2 = Vector2(x, 0) + offset
			assert(land.chunks.has(Vector2i(floori(p.x / 16), floori(p.y / 16))), "Queued border must stay ahead of the visible view")
	# Teleports and stationary resizing fill their new view immediately.
	land.stream(Vector2(80, 80), Vector2(12, 12))
	assert(land._pending_chunks.is_empty())
	land.stream(Vector2(80, 80), Vector2(30, 12))
	assert(land._pending_chunks.is_empty())
	for p in [Vector2(50, 68), Vector2(110, 92)]:
		assert(land.chunks.has(Vector2i(floori(p.x / 16), floori(p.y / 16))))
	print("Streaming smoke test passed: one chunk per moving frame, shared budget, queue cancellation, teleport and resize coverage")
	quit()
