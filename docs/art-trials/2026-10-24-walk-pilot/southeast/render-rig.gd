extends SceneTree
const DIR := "res://docs/art-trials/2026-10-24-walk-pilot/southeast/"
var bodies: Array[Image] = []
var calf: Image
var boot: Image
func green(c: Color) -> bool:
    return c.g > c.r * 0.78 and c.g > c.b * 1.30
func part(source: Image, rect: Rect2i) -> Image:
    var image := source.get_region(rect)
    image.convert(Image.FORMAT_RGBA8)
    for y in image.get_height():
        for x in image.get_width():
            var c := image.get_pixel(x,y)
            if green(c): image.set_pixel(x,y,Color.TRANSPARENT)
    return image
func paste_transformed(canvas: Image, source: Image, source_pivot: Vector2, target: Vector2, angle: float, scale: float, tint: float = 1.0) -> void:
    var corners := [Vector2.ZERO, Vector2(source.get_width(),0), Vector2(0,source.get_height()), Vector2(source.get_size())]
    var bounds := Rect2(target+(corners[0]-source_pivot).rotated(angle)*scale,Vector2.ZERO)
    for corner in corners: bounds=bounds.expand(target+(corner-source_pivot).rotated(angle)*scale)
    var layer := Image.create(canvas.get_width(),canvas.get_height(),false,Image.FORMAT_RGBA8)
    for y in range(maxi(0,floori(bounds.position.y)-1),mini(canvas.get_height(),ceili(bounds.end.y)+1)):
        for x in range(maxi(0,floori(bounds.position.x)-1),mini(canvas.get_width(),ceili(bounds.end.x)+1)):
            var p := (Vector2(x,y)-target).rotated(-angle)/scale+source_pivot
            if p.x < 0 or p.y < 0 or p.x >= source.get_width() or p.y >= source.get_height(): continue
            var c := source.get_pixel(int(p.x),int(p.y))
            if c.a <= 0: continue
            c.r*=tint; c.g*=tint; c.b*=tint
            layer.set_pixel(x,y,c)
    canvas.blend_rect(layer,Rect2i(Vector2i.ZERO,layer.get_size()),Vector2i.ZERO)
func leg(canvas: Image, phase: float, far: bool, bob: float) -> Dictionary:
    var depth := 0.9 if far else 1.0
    var hip := Vector2(247,425) if far else Vector2(310,424)
    hip.y += bob
    var center := Vector2(266,559) if far else Vector2(339,577)
    var stride := cos(phase)*35.0
    var lift := maxf(0.0,-sin(phase))*43.0
    var ankle := center+Vector2(0.6,0.8)*stride-Vector2(0,lift)
    var a := 103.0*depth
    var b := Vector2(24,64).length()*depth
    var axis := hip.direction_to(ankle)
    var distance := clampf(hip.distance_to(ankle),absf(a-b)+1.0,a+b-0.5)
    ankle=hip+axis*distance
    var along := (a*a-b*b+distance*distance)/(2.0*distance)
    var height := sqrt(maxf(0.0,a*a-along*along))
    var knee := hip+axis*along+Vector2(axis.y,-axis.x)*height
    var calf_angle := (ankle-knee).angle()-Vector2(24,64).angle()
    var foot_angle := deg_to_rad(-12.0*maxf(0.0,-sin(phase))+5.0*maxf(0.0,-cos(phase)))
    paste_transformed(canvas,calf,Vector2(27,5),knee,calf_angle,depth,0.88 if far else 1.0)
    paste_transformed(canvas,boot,Vector2(39,12),ankle,foot_angle,depth,0.88 if far else 1.0)
    return {"ankle":str(ankle),"knee":str(knee),"lift":lift,"support":sin(phase)>=0}
func _initialize() -> void:
    var strip := Image.load_from_file(DIR+"reference/current-strip.png")
    var width := strip.get_width()/4
    var first := strip.get_region(Rect2i(0,0,width,strip.get_height()))
    calf=part(first,Rect2i(303,531,78,80))
    boot=part(first,Rect2i(316,588,154,116))
    for i in 4:
        var body := strip.get_region(Rect2i(i*width,0,width,strip.get_height()))
        body.convert(Image.FORMAT_RGBA8)
        for y in range(450,body.get_height()):
            for x in body.get_width():
                var c := body.get_pixel(x,y)
                if ((x < 239 and y >= 467) or (x >= 300 and y >= 524)) and not green(c): body.set_pixel(x,y,Color.TRANSPARENT)
        bodies.append(body)
    var sheet := Image.create(1024,768,false,Image.FORMAT_RGBA8)
    var checks := []
    var body_sequence := [0,1,2,1,2,1,0,1]
    for i in 8:
        var phase := TAU*i/8.0
        var bob := -3.0*cos(2.0*phase)
        var canvas := Image.create(width,724,false,Image.FORMAT_RGBA8)
        var far_leg := leg(canvas,phase+PI,true,bob)
        var near_leg := leg(canvas,phase,false,bob)
        canvas.blend_rect(bodies[body_sequence[i]],Rect2i(Vector2i.ZERO,bodies[0].get_size()),Vector2i(0,roundi(bob)))
        canvas.resize(256,341,Image.INTERPOLATE_LANCZOS)
        var frame := Image.create(256,384,false,Image.FORMAT_RGBA8)
        frame.blend_rect(canvas,Rect2i(Vector2i.ZERO,canvas.get_size()),Vector2i(0,20))
        frame.save_png(DIR+"frames/se-%02d.png" % (i+1))
        sheet.blend_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i((i%4)*256,(i/4)*384))
        checks.append({"pose":i+1,"near":near_leg,"far":far_leg})
    sheet.save_png(DIR+"contact-sheet.png")
    var file := FileAccess.open(DIR+"rig-checks.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(checks,"  "))
    print("Rendered eight southeast cutout-rig poses with alternating support and continuous phase")
    quit()

