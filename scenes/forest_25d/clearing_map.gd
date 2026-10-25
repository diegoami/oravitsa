extends Control
var forest: Node2D
const ANIMAL_COLORS := [Color("ad7460"), Color("e8c690"), Color("f59a52"), Color("d6ad53"), Color("eee7cc")]

func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("172538"))
 var rect := Rect2(10,28,224,220)
 var extent: float = forest.landscape.EXTENT
 var convert := func(p: Vector2) -> Vector2: return rect.position+(p+Vector2.ONE*extent)/(extent*2)*rect.size
 draw_rect(rect,Color("566b3f"))
 for z in [5.0,-28.0,58.0]:
  var points := PackedVector2Array()
  for x in range(-96,97,2):
   points.append(convert.call(Vector2(x,z+0.6*sin(x*0.15))))
  draw_polyline(points,Color("a18c65"),1.5)
 for lake in forest.landscape.LAKES:
  draw_set_transform(convert.call(Vector2(lake.x,lake.y)),0,Vector2(lake.z/lake.w,1))
  draw_circle(Vector2.ZERO,lake.w/(extent*2)*rect.size.y,Color("568f89"))
  draw_set_transform(Vector2.ZERO)
 var river := PackedVector2Array()
 for z in range(-96,97):
  river.append(convert.call(Vector2(forest.landscape.river_x(z),z)))
 draw_polyline(river,Color("568f89"),3)
 var branch := PackedVector2Array()
 for p in forest.landscape.TRIBUTARY:
  branch.append(convert.call(p))
 draw_polyline(branch,Color("568f89"),3)
 for bridge in forest.landscape.bridges:
  var center: Vector2 = convert.call(Vector2(bridge.x,bridge.y))
  var direction := Vector2.from_angle(bridge.z)*4
  draw_line(center-direction,center+direction,Color("e0c69a"),3)
 for p in forest.landscape.SITES:
  draw_rect(Rect2(convert.call(p)-Vector2(3,3),Vector2(6,6)),Color("bba481"))
 for animal in forest._animals:
  if animal["alive"]:
   draw_circle(convert.call(forest.to_ground(animal["position"])),1.8,ANIMAL_COLORS[animal["kind"]])
 draw_circle(convert.call(forest.to_ground(forest.player_position)),4,Color("fff0b0"))
 draw_rect(rect,Color("bca677"),false,1)
 draw_string(ThemeDB.fallback_font,Vector2(12,20),"MOSSBANK WOODS",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ead9a9"))
 draw_string(ThemeDB.fallback_font,Vector2(12,265),"192 m · lakes, trails & ruins",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ead9a9"))
