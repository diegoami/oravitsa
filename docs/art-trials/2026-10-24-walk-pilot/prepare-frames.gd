extends SceneTree
const DIR := "res://docs/art-trials/2026-10-24-walk-pilot/"
func _initialize() -> void:
    var metrics := []
    var sheet := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
    sheet.fill(Color.TRANSPARENT)
    for index in 8:
        var image := Image.load_from_file(DIR + "raw/source-%02d.png" % (index + 1))
        image.convert(Image.FORMAT_RGBA8)
        var left := image.get_width()
        var right := 0
        var top := image.get_height()
        var bottom := 0
        for y in image.get_height():
            for x in image.get_width():
                var color := image.get_pixel(x, y)
                var distance := Vector3(color.r - 1.0, color.g, color.b - 1.0).length()
                var alpha := smoothstep(0.18, 0.46, distance)
                if alpha < 0.02:
                    color = Color.TRANSPARENT
                else:
                    color = Color(clampf((color.r - (1.0 - alpha)) / alpha, 0.0, 1.0), clampf(color.g / alpha, 0.0, 1.0), clampf((color.b - (1.0 - alpha)) / alpha, 0.0, 1.0), alpha)
                    if alpha > 0.5:
                        left = mini(left, x)
                        right = maxi(right, x)
                        top = mini(top, y)
                        bottom = maxi(bottom, y)
                var spill := maxf(0.0, minf(color.r, color.b) - color.g - 0.03)
                color.r = maxf(0.0, color.r - spill)
                color.b = maxf(0.0, color.b - spill)
                image.set_pixel(x, y, color)
        var original_size := image.get_size()
        image.resize(256, roundi(image.get_height() / 3.0), Image.INTERPOLATE_LANCZOS)
        var offset := Vector2i(0, 360 - roundi((bottom + 1) / 3.0))
        var frame := Image.create(256, 384, false, Image.FORMAT_RGBA8)
        frame.fill(Color.TRANSPARENT)
        frame.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), offset)
        var edges := 0
        for y in frame.get_height():
            for x in [0, frame.get_width() - 1]:
                if frame.get_pixel(x, y).a > 0.063: edges += 1
        for x in frame.get_width():
            for y in [0, frame.get_height() - 1]:
                if frame.get_pixel(x, y).a > 0.063: edges += 1
        assert(edges == 0, "Pilot silhouette touches frame edge")
        frame.save_png(DIR + "frames/east-%02d.png" % (index + 1))
        sheet.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i((index % 4) * 256, (index / 4) * 384))
        metrics.append({"frame": index + 1, "source_size": str(original_size), "source_body_bounds": [left, top, right, bottom], "offset": str(offset), "opaque_edge_pixels": edges})
    sheet.save_png(DIR + "contact-sheet.png")
    var file := FileAccess.open(DIR + "pixel-checks.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(metrics, "  "))
    print("Prepared eight 256x384 transparent frames, shared foot baseline 360, zero opaque frame-edge pixels")
    quit()


