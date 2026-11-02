extends RefCounted

## Names for hamlets and caves (#56), inspired by Finnish, Swedish and
## Ukrainian naming: Finnish -la/-lä farm names and -luola/-kolo caves,
## Swedish -by/-vik/-dal villages and -grottan caves, Ukrainian -ivka/-ychi
## villages and pechera caves. A name comes from the place's absolute block
## or region alone, so it never changes with streaming, rebasing or loading.

const HAMLETS := [
	"Koivula", "Kuusela", "Mäntylä", "Haapala", "Pihlajamäki", "Järvelä", "Rantala", "Kallioniemi",
	"Björkby", "Granvik", "Ekåsen", "Lindholm", "Furudal", "Älvsby", "Tallbacka", "Rönnäs",
	"Berezivka", "Sosnivka", "Dubrova", "Lypivka", "Kalynivka", "Vilshanka", "Yasenivka", "Horodnychi",
]
const CAVES := [
	"Hiidenluola", "Karhunluola", "Kivikolo", "Peikonkolo", "Ukonluola", "Kettukolo", "Pirunpesä", "Louhenluola",
	"Trollgrottan", "Björngrottan", "Jättegrytan", "Vargkulan", "Draggrottan", "Bergakungens grotta", "Mörkhålan", "Ugglegrottan",
	"Vovcha Pechera", "Kamiana Pechera", "Hlyboka Pechera", "Temna Pechera", "Dzherelna Pechera", "Vedmezha Pechera", "Zmiieva Pechera", "Sova Pechera",
]


static func _pick(pool: Array, key: Vector2i, salt: int) -> String:
	var n := (key.x * 73856093) ^ (key.y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return pool[(n & 0x7fffffff) % pool.size()]


## The name of the hamlet in absolute hamlet block `block`.
static func hamlet(block: Vector2i) -> String:
	return _pick(HAMLETS, block, 5601)


## The name of the cave in absolute landmark region `region`.
static func cave(region: Vector2i) -> String:
	return _pick(CAVES, region, 5602)
