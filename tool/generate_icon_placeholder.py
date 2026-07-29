# tool/generate_icon_placeholder.py
# One-off script: generates a placeholder app icon in the approved palette
# (coral background, white house glyph) until final artwork is supplied.
from PIL import Image, ImageDraw

SIZE = 1024
BG = (244, 162, 97)  # #F4A261 coral
FG = (255, 255, 255)

img = Image.new("RGB", (SIZE, SIZE), BG)
draw = ImageDraw.Draw(img)

body_w, body_h = 420, 320
body_left = (SIZE - body_w) // 2
body_top = SIZE // 2 - 20
draw.rectangle(
    [body_left, body_top, body_left + body_w, body_top + body_h],
    fill=FG,
)

roof_height = 260
roof_overhang = 40
roof_points = [
    (body_left - roof_overhang, body_top),
    (body_left + body_w + roof_overhang, body_top),
    (body_left + body_w / 2, body_top - roof_height),
]
draw.polygon(roof_points, fill=FG)

door_w, door_h = 100, 160
door_left = body_left + (body_w - door_w) // 2
door_top = body_top + body_h - door_h
draw.rectangle(
    [door_left, door_top, door_left + door_w, door_top + door_h],
    fill=BG,
)

img.save("assets/icon/icon.png")
print("Saved assets/icon/icon.png", img.size)
