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


## Names step through the pool on a lattice (x + 5 y), so neighbours always
## differ: the closest places sharing a name are (-1, 5), (4, 4) or (-5, 1)
## blocks or regions apart, at least about 690 m for caves (256 × 128 m
## regions) and 1.9 km for hamlets (512 × 384 m blocks).
static func _pick(pool: Array, key: Vector2i, offset: int) -> String:
	return pool[posmod(key.x + key.y * 5 + offset, pool.size())]


## The name of the hamlet in absolute hamlet block `block`.
static func hamlet(block: Vector2i) -> String:
	return _pick(HAMLETS, block, 0)


## The name of the cave in absolute landmark region `region`.
static func cave(region: Vector2i) -> String:
	return _pick(CAVES, region, 11)
