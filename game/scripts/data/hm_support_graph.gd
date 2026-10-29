class_name HMSupportGraph
extends RefCounted
## Directed support graph. An edge support -> dependent means the support
## must be removed after its dependent for intact, orderly dismantling.
## No world mutation: read-only diagnostics for inspection and safe release.


static func direct_dependents(catalog: HMCatalog, support_id: String, active: Array) -> Array[String]:
	var definition: Dictionary = catalog.by_part_id(support_id)
	var result: Array[String] = []
	if definition.is_empty():
		return result
	for raw: Variant in definition.get("supports", []):
		var pid: String = String(raw)
		if active.has(pid):
			result.append(pid)
	result.sort()
	return result


static func cascade(catalog: HMCatalog, support_id: String, active: Array) -> Dictionary:
	# Returns all unique still-attached descendants, deterministic ordering,
	# regardless of topology/cycle. Graph validation is a separate schema gate.
	var visited: Dictionary = {}
	visited[support_id] = true
	var frontier: Array[String] = [support_id]
	var damaged: Array[String] = []
	var protected_ids: Array[String] = []
	while not frontier.is_empty():
		var source: String = frontier.pop_front()
		for pid: String in direct_dependents(catalog, source, active):
			if visited.has(pid):
				continue
			visited[pid] = true
			damaged.append(pid)
			if bool(catalog.by_part_id(pid).get("protected", false)):
				protected_ids.append(pid)
			frontier.append(pid)
	damaged.sort()
	protected_ids.sort()
	return {"dependent_ids": damaged, "protected_ids": protected_ids,
		"count": damaged.size(), "truncated": damaged.size() > 4}


static func release_diagnostic(catalog: HMCatalog, support_id: String, active: Array) -> Dictionary:
	var part: Dictionary = catalog.by_part_id(support_id)
	if part.is_empty() or not active.has(support_id):
		return {"allowed_safe": false, "reason": "Component is unavailable", "direct_ids": []}
	if bool(part.get("protected", false)):
		return {"allowed_safe": false, "reason": "Protected structural or story component", "direct_ids": []}
	var direct: Array[String] = direct_dependents(catalog, support_id, active)
	var downstream: Dictionary = cascade(catalog, support_id, active)
	var blocked: bool = not direct.is_empty()
	var message: String = "No loaded dependents — safe structural order"
	if blocked:
		message = "First release supported components: " + ", ".join(direct)
		if not downstream["protected_ids"].is_empty():
			message += " (protected dependency — cannot force)"
		elif bool(downstream["truncated"]):
			message += " (cascade exceeds local damage limit)"
	return {"allowed_safe": not blocked, "reason": message,
		"direct_ids": direct, "cascade_ids": downstream["dependent_ids"],
		"protected_ids": downstream["protected_ids"], "truncated": downstream["truncated"]}
