class_name GooglePlayStore
extends StoreBackend
## Google Play Billing through the godot-google-play-billing plugin (v3+, Godot 4.2+).
## Talks to the plugin's JNI singleton directly, so this file parses on every platform.
## Non-consumables are acknowledged; consumables are granted only once Play confirms the consume.

const SINGLETON := "GodotGooglePlayBilling"
const OK_CODE := 0
const USER_CANCELED := 1
const ITEM_ALREADY_OWNED := 7
const PURCHASED_STATE := 1
const PENDING_STATE := 2

var _play: Object
var _ids := PackedStringArray()
var _consumables := PackedStringArray()
var _connected := false
var _restoring := false
## Purchase tokens handled this session, so a purchase is never granted twice.
var _handled := {}
## Consume token -> product id, granted when the consume response arrives.
var _consuming := {}


func start(ids: PackedStringArray, consumables: PackedStringArray) -> void:
	_ids = ids
	_consumables = consumables
	_play = Engine.get_singleton(SINGLETON)
	_play.initPlugin()
	_play.connect("connected", _on_connected)
	_play.connect("disconnected", _on_disconnected)
	_play.connect("connect_error", _on_connect_error)
	_play.connect("query_product_details_response", _on_product_details)
	_play.connect("query_purchases_response", _on_query_purchases)
	_play.connect("on_purchase_updated", _on_purchase_updated)
	_play.connect("consume_purchase_response", _on_consumed)
	_play.connect("acknowledge_purchase_response", _on_acknowledged)
	_play.startConnection()


func is_ready() -> bool:
	return _connected


func purchase(store_id: String) -> void:
	var result: Dictionary = _play.purchase(store_id, "", "", false)
	var code := int(result.get("response_code", OK_CODE))
	if code != OK_CODE:
		failed.emit(store_id, _describe(code))


func restore() -> void:
	_restoring = true
	_play.queryPurchases("inapp", false)


func _on_connected() -> void:
	_connected = true
	_play.queryProductDetails(_ids, "inapp")
	# Picks up purchases made elsewhere or never acknowledged (e.g. the app closed mid-flow).
	_play.queryPurchases("inapp", false)


func _on_disconnected() -> void:
	_connected = false


func _on_connect_error(_code: int, message: String) -> void:
	_connected = false
	push_warning("Play Billing connection failed: %s" % message)


func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != OK_CODE:
		return
	for details: Dictionary in response.get("product_details", []):
		var offers: Variant = details.get("one_time_purchase_offer_details_list")
		var offer: Variant = offers[0] if offers is Array and not offers.is_empty() else details.get("one_time_purchase_offer_details")
		if offer is Dictionary:
			product_info.emit(str(details.get("product_id", "")), str(offer.get("formatted_price", "")))


func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	var purchases: Array = response.get("purchases", [])
	if code == OK_CODE:
		for item: Dictionary in purchases:
			_handle(item, false)
	elif code == ITEM_ALREADY_OWNED:
		restore()
	else:
		var store_id: String = _first_product(purchases)
		failed.emit(store_id, _describe(code))


func _on_query_purchases(response: Dictionary) -> void:
	var ok := int(response.get("response_code", -1)) == OK_CODE
	var count := 0
	if ok:
		for item: Dictionary in response.get("purchases", []):
			if _handle(item, true):
				count += 1
	if _restoring:
		_restoring = false
		restore_done.emit(ok, count)


## Returns true when the purchase was (or will be) granted.
func _handle(item: Dictionary, from_restore: bool) -> bool:
	var token := str(item.get("purchase_token", ""))
	var store_id := _first_product([item])
	var state := int(item.get("purchase_state", 0))
	if state == PENDING_STATE:
		if not from_restore:
			failed.emit(store_id, "Payment pending. It will unlock once it completes.")
		return false
	if state != PURCHASED_STATE or token.is_empty():
		return false
	if store_id in _consumables:
		if not _consuming.has(token):
			_consuming[token] = store_id
			_play.consumePurchase(token)
		return true
	if not _handled.has(token):
		_handled[token] = true
		purchased.emit(store_id, from_restore)
	if not bool(item.get("is_acknowledged", false)):
		_play.acknowledgePurchase(token)
	return true


func _on_consumed(response: Dictionary) -> void:
	var token := str(response.get("token", ""))
	var store_id: String = _consuming.get(token, "")
	if store_id.is_empty():
		return
	_consuming.erase(token)
	# On failure the purchase stays unconsumed in Play, so the next query retries it; shards are
	# only ever granted on a confirmed consume, never twice.
	if int(response.get("response_code", -1)) == OK_CODE:
		purchased.emit(store_id, false)


func _on_acknowledged(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != OK_CODE:
		push_warning("Play Billing acknowledge failed: %s" % response.get("debug_message", ""))


static func _first_product(purchases: Array) -> String:
	for item: Dictionary in purchases:
		var ids: Variant = item.get("product_ids", [])
		if ids is Array and not ids.is_empty():
			return str(ids[0])
		if ids is PackedStringArray and not ids.is_empty():
			return ids[0]
	return ""


static func _describe(code: int) -> String:
	match code:
		USER_CANCELED:
			return "Purchase cancelled."
		2, 12, -1, -3:
			return "Could not reach Google Play. Check your connection."
		3:
			return "Billing is not available on this device."
		4:
			return "This item is not available right now."
		ITEM_ALREADY_OWNED:
			return "You already own this. Restoring it now."
	return "The purchase did not go through (code %d)." % code
