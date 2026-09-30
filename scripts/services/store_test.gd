class_name TestStore
extends StoreBackend
## Desktop debug-build store: approves every purchase after a short delay so the shop flow can
## be exercised without a device. Never used in release builds.

const DELAY := 0.6


func is_ready() -> bool:
	return true


func purchase(store_id: String) -> void:
	await Engine.get_main_loop().create_timer(DELAY).timeout
	purchased.emit(store_id, false)


func restore() -> void:
	await Engine.get_main_loop().create_timer(DELAY).timeout
	restore_done.emit(true, 0)
