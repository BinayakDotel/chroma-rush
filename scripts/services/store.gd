extends Node
## In-app purchases, autoloaded as `Store`. Picks a backend at startup:
##   Android  - Google Play Billing plugin (singleton "GodotGooglePlayBilling")
##   iOS      - StoreKit 2 plugin (class "GodotStoreKit2")
##   desktop debug builds - a local test store that approves every purchase
## With none of these, the store reports itself unavailable and the UI hides purchase buttons.
## Every grant goes through Profile, so entitlements survive restarts; non-consumables can also
## be restored from the store account.

signal products_updated
signal purchase_finished(product_id: String, ok: bool, message: String)
signal restore_finished(ok: bool, message: String)

const ID_PREFIX := "com.binayakdotel.chromarush."

## Catalogue. `grants` are entitlements; `shards` are added for consumables.
## `live` = false keeps a product out of the shop until it is switched on.
const PRODUCTS := {
	"supporter_pack": {
		"title": "Supporter Pack", "price": "$5.99", "consumable": false, "live": true,
		"blurb": "No forced ads, every world, double shards forever.",
		"grants": [Economy.NO_ADS, Economy.ALL_WORLDS, Economy.DOUBLE_SHARDS],
	},
	"world_pass": {
		"title": "World Pass", "price": "$3.99", "consumable": false, "live": true,
		"blurb": "Unlock every world, including future ones.",
		"grants": [Economy.ALL_WORLDS],
	},
	"no_ads": {
		"title": "No Ads", "price": "$2.99", "consumable": false, "live": true,
		"blurb": "Removes ads between runs. Rewarded ads stay optional.",
		"grants": [Economy.NO_ADS],
	},
	"shards_small": {
		"title": "Pouch of Shards", "price": "$0.99", "consumable": true, "live": false,
		"blurb": "1,000 shards.", "shards": 1000,
	},
	"shards_large": {
		"title": "Chest of Shards", "price": "$3.99", "consumable": true, "live": false,
		"blurb": "6,000 shards.", "shards": 6000,
	},
}

var backend: StoreBackend
## Localised prices reported by the store, keyed by short product id.
var _prices := {}
var _busy := false


func _ready() -> void:
	if Engine.has_singleton(GooglePlayStore.SINGLETON):
		backend = GooglePlayStore.new()
	elif ClassDB.class_exists(AppleStore.CLASS_NAME):
		backend = AppleStore.new()
	elif OS.is_debug_build():
		backend = TestStore.new()
	if backend == null:
		return
	backend.product_info.connect(_on_product_info)
	backend.purchased.connect(_on_purchased)
	backend.failed.connect(_on_failed)
	backend.restore_done.connect(_on_restore_done)
	backend.start(_store_ids(), _consumable_store_ids())


func is_available() -> bool:
	return backend != null and backend.is_ready()


## False where there is no store at all (web builds); the UI then leaves the shop out.
func is_supported() -> bool:
	return backend != null


func is_busy() -> bool:
	return _busy


func live_products() -> Array[String]:
	var ids: Array[String] = []
	for id: String in PRODUCTS:
		if PRODUCTS[id].live:
			ids.append(id)
	return ids


func price(id: String) -> String:
	return _prices.get(id, PRODUCTS[id].price)


## True when a non-consumable's entitlements are all owned already.
func is_owned(id: String) -> bool:
	var product: Dictionary = PRODUCTS[id]
	if product.consumable:
		return false
	for entitlement: StringName in product.grants:
		if not Profile.has_entitlement(entitlement):
			return false
	return true


func purchase(id: String) -> void:
	if not PRODUCTS.has(id) or is_owned(id):
		return
	if not is_available():
		purchase_finished.emit(id, false, "The store is not available right now.")
		return
	if _busy:
		return
	_busy = true
	backend.purchase(ID_PREFIX + id)


func restore() -> void:
	if not is_available():
		restore_finished.emit(false, "The store is not available right now.")
		return
	_busy = true
	backend.restore()


func _on_product_info(store_id: String, localized_price: String) -> void:
	var id := _short(store_id)
	if PRODUCTS.has(id) and not localized_price.is_empty():
		_prices[id] = localized_price
		products_updated.emit()


func _on_purchased(store_id: String, from_restore: bool) -> void:
	var id := _short(store_id)
	if not PRODUCTS.has(id):
		return
	var product: Dictionary = PRODUCTS[id]
	if product.consumable:
		Profile.add_shards(int(product.shards))
	else:
		for entitlement: StringName in product.grants:
			Profile.grant(entitlement)
	if not from_restore:
		_busy = false
		purchase_finished.emit(id, true, "%s unlocked. Thank you!" % product.title)


func _on_failed(store_id: String, message: String) -> void:
	_busy = false
	purchase_finished.emit(_short(store_id), false, message)


func _on_restore_done(ok: bool, count: int) -> void:
	_busy = false
	if not ok:
		restore_finished.emit(false, "Could not reach the store. Try again later.")
	elif count == 0:
		restore_finished.emit(true, "No purchases to restore.")
	else:
		restore_finished.emit(true, "Purchases restored.")


func _short(store_id: String) -> String:
	return store_id.trim_prefix(ID_PREFIX)


func _store_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: String in PRODUCTS:
		ids.append(ID_PREFIX + id)
	return ids


func _consumable_store_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: String in PRODUCTS:
		if PRODUCTS[id].consumable:
			ids.append(ID_PREFIX + id)
	return ids
