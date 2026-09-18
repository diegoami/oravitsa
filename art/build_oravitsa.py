"""Build the Oravitsa game mesh into art/oravitsa.blend.

    blender --background art/oravitsa.blend --python art/build_oravitsa.py

Everything is lofted from horizontal cross-sections taken at the landmark
heights in docs/character.md, which gives continuous quad topology that can be
rigged and deformed -- unlike the primitive blockout, which is 34 separate
floating solids.

Axes in here are Blender's: +Z is up, and +Y is the character's FRONT. That
follows from the glTF round trip -- Blender +Y becomes Godot -Z, and -Z is
Godot's forward. Get this backwards and she walks backwards.

Budget is about 1,500 triangles: she is roughly 160 px tall on screen, so the
job is silhouette and flat colour, not detail. Smooth shading rather than
subdivision keeps the count down while keeping the curves clean.
"""
import math
import sys
import bmesh
import bpy
from mathutils import Vector

COLLECTION = "Oravitsa"

# docs/character.md -- the named palette, plus the sampled values for the
# things the sheet does not name.
PALETTE = {
    "blue":    (0.216, 0.275, 0.376),
    "yellow":  (0.820, 0.647, 0.294),
    "linen":   (0.804, 0.769, 0.722),
    "birch":   (0.600, 0.557, 0.514),
    "moss":    (0.337, 0.349, 0.282),
    "leather": (0.275, 0.227, 0.227),
    "hair":    (0.505, 0.418, 0.340),
    "skin":    (0.925, 0.800, 0.706),
    "amber":   (0.710, 0.408, 0.129),
    "wicker":  (0.478, 0.369, 0.275),
    "eye":     (0.424, 0.486, 0.549),
}

SEG = 14        # radial segments on organic forms
SEG_FINE = 16   # head


# --------------------------------------------------------------------------
# helpers


def srgb_to_linear(c):
    """docs/character.md stores the palette as sRGB, which is what Godot's
    albedo_color wants. Blender's Principled base colour is LINEAR, so the
    values have to be converted or every surface comes out washed out."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key):
    name = f"Oravitsa_{key}"
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        r, g, b = (srgb_to_linear(c) for c in PALETTE[key])
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.15
        mat.diffuse_color = (r, g, b, 1.0)
    return mat


def ellipse_ring(z, rx, ry, n=SEG, xoff=0.0, yoff=0.0):
    """A horizontal ellipse of n points, centred at (xoff, yoff, z)."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        pts.append(Vector((xoff + math.cos(a) * rx,
                           yoff + math.sin(a) * ry,
                           z)))
    return pts


def hair_ring(z, rx, ry, n, yoff=0.0, front=0.60):
    """An ellipse pulled in at the FRONT (+Y), so the hair passes behind the
    face instead of over it. Full radius at the sides and back."""
    pts = []
    for i in range(n):
        a = math.tau * i / n
        s = math.sin(a)
        t = max(0.0, min(1.0, (s - 0.10) / 0.90))
        k = 1.0 - t * (1.0 - front)
        pts.append(Vector((math.cos(a) * rx * k, yoff + s * ry * k, z)))
    return pts


def rect_ring(z, hw, hd, xoff=0.0, yoff=0.0):
    """A flat rectangular cross-section, for ribbons like the bandana tails."""
    return [
        Vector((xoff - hw, yoff - hd, z)),
        Vector((xoff + hw, yoff - hd, z)),
        Vector((xoff + hw, yoff + hd, z)),
        Vector((xoff - hw, yoff + hd, z)),
    ]


def loft(rings, cap_start=True, cap_end=True):
    """Bridge a stack of equal-length rings into a closed quad surface."""
    bm = bmesh.new()
    layers = []
    for ring in rings:
        layers.append([bm.verts.new(p) for p in ring])
    bm.verts.ensure_lookup_table()

    for lower, upper in zip(layers, layers[1:]):
        n = len(lower)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lower[i], lower[j], upper[j], upper[i]))

    if cap_start:
        bm.faces.new(layers[0][::-1])
    if cap_end:
        bm.faces.new(layers[-1])

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def emit(name, bm, key, smooth=True, collection=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    mesh.materials.append(material(key))
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def mirrored(name, build, key, smooth=True, collection=None):
    """Build a part on +X and mirror it to -X."""
    made = []
    for side, sign in (("R", 1.0), ("L", -1.0)):
        bm = build(sign)
        made.append(emit(f"{name}_{side}", bm, key, smooth, collection))
    return made


# --------------------------------------------------------------------------
# the figure -- every z below is a landmark from docs/character.md


def build_tunic(col):
    rings = [
        ellipse_ring(1.150, 0.150, 0.100),
        ellipse_ring(1.140, 0.165, 0.106),   # shoulder, 34 cm across
        ellipse_ring(1.080, 0.152, 0.100),
        ellipse_ring(1.000, 0.140, 0.094),
        ellipse_ring(0.930, 0.132, 0.090),
        ellipse_ring(0.910, 0.130, 0.089),   # waist
        ellipse_ring(0.870, 0.145, 0.100),
        ellipse_ring(0.820, 0.160, 0.111),
        ellipse_ring(0.780, 0.170, 0.118),   # hem, drapes over the skirt
    ]
    emit("Tunic", loft(rings), "linen", collection=col)


def build_skirt(col):
    rings = [
        ellipse_ring(0.920, 0.138, 0.096),   # tucked under the belt
        ellipse_ring(0.750, 0.155, 0.112),
        ellipse_ring(0.550, 0.170, 0.128),
        ellipse_ring(0.350, 0.182, 0.140),
        ellipse_ring(0.280, 0.186, 0.144),   # hem, mid-calf
    ]
    emit("Skirt", loft(rings), "moss", collection=col)


def build_belt(col):
    rings = [
        ellipse_ring(0.884, 0.150, 0.108),
        ellipse_ring(0.936, 0.150, 0.108),
    ]
    emit("Belt", loft(rings), "leather", smooth=False, collection=col)
    buckle = loft([
        rect_ring(0.894, 0.026, 0.012, yoff=0.109),
        rect_ring(0.926, 0.026, 0.012, yoff=0.109),
    ])
    emit("Buckle", buckle, "yellow", smooth=False, collection=col)
    pouch = loft([
        rect_ring(0.800, 0.032, 0.024, xoff=0.132, yoff=0.052),
        rect_ring(0.884, 0.032, 0.024, xoff=0.132, yoff=0.052),
    ])
    emit("Pouch", pouch, "leather", smooth=False, collection=col)


def build_head(col):
    rings = [ellipse_ring(1.470, 0.020, 0.022, SEG_FINE)]
    for z, rx, ry in [
        (1.450, 0.058, 0.066), (1.420, 0.082, 0.094), (1.380, 0.093, 0.108),
        (1.340, 0.095, 0.112), (1.305, 0.093, 0.109), (1.272, 0.086, 0.100),
        (1.248, 0.072, 0.084),
    ]:
        rings.append(ellipse_ring(z, rx, ry, SEG_FINE))
    rings.append(ellipse_ring(1.230, 0.050, 0.058, SEG_FINE))
    emit("Head", loft(rings), "skin", collection=col)

    neck = [ellipse_ring(1.130, 0.056, 0.056, 10),
            ellipse_ring(1.225, 0.048, 0.050, 10)]
    emit("Neck", loft(neck), "skin", collection=col)

    def eye(sign):
        return loft([
            ellipse_ring(1.312, 0.014, 0.008, 8, xoff=sign * 0.040, yoff=0.104),
            ellipse_ring(1.330, 0.019, 0.011, 8, xoff=sign * 0.040, yoff=0.110),
            ellipse_ring(1.348, 0.013, 0.007, 8, xoff=sign * 0.040, yoff=0.104),
        ])
    mirrored("Eye", eye, "eye", collection=col)


def build_hair(col):
    """A shell over the skull plus the mass falling behind. The bandana covers
    the crown, so only the sides and the back need to read."""
    rings = [hair_ring(1.468, 0.030, 0.034, SEG_FINE)]
    for z, rx, ry, yo in [
        (1.445, 0.068, 0.078, -0.002), (1.415, 0.094, 0.108, -0.004),
        (1.375, 0.107, 0.123, -0.006), (1.338, 0.118, 0.134, -0.008),
        (1.290, 0.121, 0.136, -0.012), (1.240, 0.118, 0.131, -0.018),
        (1.180, 0.110, 0.119, -0.026), (1.120, 0.098, 0.103, -0.032),
    ]:
        rings.append(hair_ring(z, rx, ry, SEG_FINE, yoff=yo))
    rings.append(hair_ring(1.090, 0.074, 0.076, SEG_FINE, yoff=-0.034))
    emit("Hair", loft(rings), "hair", collection=col)

    def braid(sign):
        rings = []
        for z, r, xo, yo in [
            (1.245, 0.026, 0.092, 0.050), (1.180, 0.029, 0.098, 0.066),
            (1.110, 0.027, 0.103, 0.076), (1.040, 0.023, 0.106, 0.080),
            (0.995, 0.018, 0.107, 0.080),
        ]:
            rings.append(ellipse_ring(z, r, r, 8, xoff=sign * xo, yoff=yo))
        return loft(rings)
    mirrored("Braid", braid, "hair", collection=col)

    def bead(sign):
        return loft([
            ellipse_ring(0.996, 0.010, 0.010, 8, xoff=sign * 0.107, yoff=0.080),
            ellipse_ring(0.978, 0.026, 0.026, 8, xoff=sign * 0.107, yoff=0.080),
            ellipse_ring(0.958, 0.026, 0.026, 8, xoff=sign * 0.107, yoff=0.080),
            ellipse_ring(0.942, 0.010, 0.010, 8, xoff=sign * 0.107, yoff=0.080),
        ])
    mirrored("Bead", bead, "amber", collection=col)


def build_bandana(col):
    cap = [ellipse_ring(1.500, 0.022, 0.024, SEG_FINE)]
    for z, rx, ry in [
        (1.482, 0.060, 0.068), (1.452, 0.088, 0.100), (1.412, 0.102, 0.117),
        (1.372, 0.107, 0.124), (1.344, 0.108, 0.126),
    ]:
        cap.append(ellipse_ring(z, rx, ry, SEG_FINE))
    emit("BandanaCap", loft(cap, cap_end=False), "blue", collection=col)

    band = [ellipse_ring(1.346, 0.114, 0.132, SEG_FINE),
            ellipse_ring(1.376, 0.113, 0.130, SEG_FINE)]
    emit("BandanaBand", loft(band, cap_start=False, cap_end=False),
         "yellow", collection=col)

    knot = loft([
        ellipse_ring(1.372, 0.016, 0.016, 8, yoff=-0.128),
        ellipse_ring(1.352, 0.038, 0.034, 8, yoff=-0.140),
        ellipse_ring(1.326, 0.034, 0.030, 8, yoff=-0.140),
        ellipse_ring(1.308, 0.014, 0.014, 8, yoff=-0.130),
    ])
    emit("BandanaKnot", knot, "blue", collection=col)

    # The tails are the character's strongest motion cue -- they splay out to
    # the sides, which is how the top-down sheet shows them and the only way
    # they read from a fixed isometric camera.
    def tail(sign):
        rings = []
        for z, hw, xo, yo in [
            (1.352, 0.020, 0.052, -0.132), (1.300, 0.023, 0.090, -0.158),
            (1.240, 0.021, 0.126, -0.176), (1.180, 0.016, 0.150, -0.188),
            (1.140, 0.009, 0.162, -0.194),
        ]:
            rings.append(rect_ring(z, hw, 0.007, xoff=sign * xo, yoff=yo))
        return loft(rings)
    mirrored("BandanaTail", tail, "blue", smooth=False, collection=col)


def build_arms(col):
    def sleeve(sign):
        rings = []
        for z, r, xo in [
            (1.148, 0.044, 0.150), (1.090, 0.046, 0.158), (1.010, 0.042, 0.166),
            (0.955, 0.038, 0.170),
        ]:
            rings.append(ellipse_ring(z, r, r * 0.92, 10, xoff=sign * xo))
        return loft(rings)
    mirrored("Sleeve", sleeve, "linen", collection=col)

    def forearm(sign):
        rings = []
        for z, r, xo in [
            (0.960, 0.034, 0.170), (0.880, 0.031, 0.174), (0.780, 0.027, 0.178),
            (0.720, 0.028, 0.180), (0.680, 0.022, 0.180),
        ]:
            rings.append(ellipse_ring(z, r, r * 0.9, 10, xoff=sign * xo))
        return loft(rings)
    mirrored("Forearm", forearm, "skin", collection=col)


def build_legs(col):
    def leg(sign):
        rings = []
        for z, r, xo in [
            (0.480, 0.058, 0.066), (0.340, 0.054, 0.066), (0.282, 0.052, 0.066),
            (0.230, 0.050, 0.066), (0.196, 0.047, 0.066),
        ]:
            rings.append(ellipse_ring(z, r, r, 10, xoff=sign * xo))
        return loft(rings)
    mirrored("Sock", leg, "birch", collection=col)

    def boot(sign):
        rings = []
        for z, rx, ry, yo in [
            (0.200, 0.052, 0.058, 0.000), (0.140, 0.055, 0.070, 0.012),
            (0.070, 0.056, 0.082, 0.024), (0.020, 0.055, 0.086, 0.030),
            (0.000, 0.050, 0.080, 0.030),
        ]:
            rings.append(ellipse_ring(z, rx, ry, 10, xoff=sign * 0.066, yoff=yo))
        return loft(rings)
    mirrored("Boot", boot, "leather", smooth=False, collection=col)


def build_basket(col):
    rings = [
        ellipse_ring(0.810, 0.098, 0.076, SEG, yoff=-0.170),
        ellipse_ring(0.900, 0.114, 0.088, SEG, yoff=-0.172),
        ellipse_ring(1.040, 0.128, 0.099, SEG, yoff=-0.174),
        ellipse_ring(1.160, 0.136, 0.106, SEG, yoff=-0.175),
    ]
    obj = emit("Basket", loft(rings, cap_end=False), "wicker", collection=col)
    # Open-topped, so give the wall real thickness rather than leaving a
    # zero-width shell that shows its backfaces from above.
    solid = obj.modifiers.new("Wall", "SOLIDIFY")
    solid.thickness = 0.014
    solid.offset = 1.0

    def strap(sign):
        rings = []
        for z, hw, xo, yo in [
            (1.150, 0.020, 0.068, 0.084), (1.060, 0.019, 0.072, 0.092),
            (0.960, 0.018, 0.074, 0.090), (0.910, 0.017, 0.074, 0.086),
        ]:
            rings.append(rect_ring(z, hw, 0.008, xoff=sign * xo, yoff=yo))
        return loft(rings)
    mirrored("Strap", strap, "leather", smooth=False, collection=col)

    def greens(sign):
        return loft([
            ellipse_ring(1.150, 0.020, 0.018, 8, xoff=sign * 0.048, yoff=-0.175),
            ellipse_ring(1.180, 0.046, 0.040, 8, xoff=sign * 0.048, yoff=-0.175),
            ellipse_ring(1.205, 0.030, 0.026, 8, xoff=sign * 0.048, yoff=-0.175),
        ])
    mirrored("Greens", greens, "moss", collection=col)


# --------------------------------------------------------------------------


def main():
    col = bpy.data.collections.get(COLLECTION)
    if col is None:
        sys.exit(f"no collection named {COLLECTION!r} -- run setup_blend.py first")

    for obj in list(col.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    build_tunic(col)
    build_skirt(col)
    build_belt(col)
    build_head(col)
    build_hair(col)
    build_bandana(col)
    build_arms(col)
    build_legs(col)
    build_basket(col)

    tris = 0
    lo, hi = float("inf"), float("-inf")
    for obj in col.objects:
        mesh = obj.data
        for poly in mesh.polygons:
            tris += max(1, len(poly.vertices) - 2)
        for corner in obj.bound_box:
            z = (obj.matrix_world @ Vector(corner)).z
            lo, hi = min(lo, z), max(hi, z)

    print(f"OBJECTS={len(col.objects)}")
    print(f"TRIS={tris}")
    print(f"BOUNDS_Z={lo:.4f}..{hi:.4f}")
    print(f"HEIGHT={hi - lo:.4f}")
    bpy.ops.wm.save_mainfile()
    print("SAVED")


main()
