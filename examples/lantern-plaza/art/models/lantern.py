"""Street lantern: tapered iron post, scrolled arms, glass lantern box with a pointed cap.
Units are studs. Base sits at Z=0. The glowing bulb is a separate Neon part added in the map,
so the light can be switched on and off by scripts."""

ROBLOX_MATERIALS = {
    "Post": "Metal",
    "Base": "Metal",
    "Cage": "Metal",
    "Cap": "Metal",
    "Glass": "Glass",
}


def build(bpy, kit):
    iron = kit.mat("iron", "#22261f", rough=0.45, metal=0.8)
    glass = kit.mat("glass", "#ffe2a6", rough=0.1, emit=0.0)

    # turned base + post (lathe profile: radius, height)
    kit.lathe("Base", [
        (0.0, 0.0), (0.95, 0.0), (0.95, 0.18), (0.75, 0.3), (0.72, 0.55), (0.5, 0.7),
        (0.42, 0.95), (0.36, 1.05), (0.0, 1.05),
    ], mat=iron)
    kit.lathe("Post", [
        (0.0, 1.0), (0.26, 1.0), (0.22, 1.6), (0.19, 3.4), (0.24, 3.55), (0.24, 3.7),
        (0.3, 3.8), (0.0, 3.8),
    ], mat=iron)

    # lantern cage: four corner bars + rings
    for sx in (-1, 1):
        for sy in (-1, 1):
            kit.box("Cage", 0.08, 0.08, 1.25, sx * 0.48, sy * 0.48, 3.85, mat=iron)
    kit.box("Cage", 1.15, 1.15, 0.1, 0, 0, 3.8, mat=iron, bevel=0.02)
    kit.box("Cage", 1.15, 1.15, 0.1, 0, 0, 5.05, mat=iron, bevel=0.02)

    # glass panels (one box, slightly inset)
    kit.box("Glass", 0.9, 0.9, 1.15, 0, 0, 3.9, mat=glass)

    # pointed cap with finial
    kit.cone("Cap", 0.85, 0.12, 0.7, 5.15, verts=4, mat=iron)
    bpy.context.active_object.rotation_euler[2] = 0.7853981634
    kit.sphere("Cap", 0.13, 5.95, mat=iron, segs=16)
