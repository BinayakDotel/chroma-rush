class_name AppleStore
extends StoreBackend
## App Store purchases through the godot-storekit2 plugin. The plugin class only exists in iOS
## builds, so it is created by name through ClassDB and used without static types.

const CLASS_NAME := "GodotStoreKit2"
# godot-storekit2 TransactionState values.
const PENDING := 2
const DEFERRED := 3
const PURCHASED := 4
const RESTORED := 5
const CANCELED := 7

var _kit: Object
var _ids := PackedStringArray()
var _consumables := PackedStringArray()
var _restoring := false
var _restore_count := 0
var _restore_pending := 0


func start(ids: PackedStringArray, consumables: PackedStringArray) -> void:
	_ids = ids
	_consumables = consumables
	_kit = ClassDB.instantiate(CLASS_NAME)
	_kit.connect("transaction_state_changed", _on_transaction)
	_kit.connect("product_info_received", _on_product_info)
	_kit.connect("synchronized", _on_synchronized)
	for id in _ids:
		_kit.request_product_info(id)


func is_ready() -> bool:
	return _kit != null


func purchase(store_id: String) -> void:
	_kit.purchase_product(store_id, 1)


## Re-syncs with the App Store (asks the player to sign in), then re-reads ownership.
func restore() -> void:
	_restoring = true
	_restore_count = 0
	_kit.sync()


func _on_synchronized() -> void:
	if not _restoring:
		return
	_restore_pending = 0
	for id in _ids:
		if not id in _consumables:
			_restore_pending += 1
			_kit.request_product_info(id)
	if _restore_pending == 0:
		_finish_restore(true)


func _on_product_info(info: Dictionary) -> void:
	var error := str(info.get("error", ""))
	var store_id := str(info.get("product_id", ""))
	if error.is_empty():
		product_info.emit(store_id, str(info.get("localized_price", "")))
		# StoreKit 2 reports current ownership of non-consumables with the product info.
		if bool(info.get("is_purchased", false)) and not store_id in _consumables:
			purchased.emit(store_id, true)
			if _restoring:
				_restore_count += 1
	if _restoring and not store_id in _consumables:
		_restore_pending -= 1
		if _restore_pending <= 0:
			_finish_restore(true)


func _on_transaction(transaction: Dictionary) -> void:
	var error := str(transaction.get("error", ""))
	var store_id := str(transaction.get("product_id", ""))
	if not error.is_empty():
		failed.emit(store_id, "The purchase did not go through.")
		return
	match int(transaction.get("transaction_state", -1)):
		PURCHASED, RESTORED:
			purchased.emit(store_id, false)
		PENDING, DEFERRED:
			failed.emit(store_id, "Waiting for approval. It will unlock once approved.")
		CANCELED:
			failed.emit(store_id, "Purchase cancelled.")
		_:
			failed.emit(store_id, "The purchase did not go through.")


func _finish_restore(ok: bool) -> void:
	_restoring = false
	restore_done.emit(ok, _restore_count)
