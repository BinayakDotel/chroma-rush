class_name StoreBackend
extends RefCounted
## Interface between Store and a platform billing API. Backends report prices, completed
## purchases (including ones found while restoring) and failures through these signals.

@warning_ignore("unused_signal")
signal product_info(store_id: String, localized_price: String)
@warning_ignore("unused_signal")
signal purchased(store_id: String, from_restore: bool)
@warning_ignore("unused_signal")
signal failed(store_id: String, message: String)
@warning_ignore("unused_signal")
signal restore_done(ok: bool, count: int)


func start(_ids: PackedStringArray, _consumables: PackedStringArray) -> void:
	pass


func is_ready() -> bool:
	return false


func purchase(_store_id: String) -> void:
	pass


func restore() -> void:
	pass
