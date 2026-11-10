"""Genera l'icona dell'app: un manubrio inclinato su gradiente petrolio.

Il disegno viene dal canvas "Icona app myWorkout" fatto con Claude
(tre varianti: chiara, scura e monocromatica). Qui lo ridisegniamo con
Pillow, forma per forma, così non serve nessun programma per leggere SVG.

Uso:  python tool/generate_app_icon.py
Poi:  dart run flutter_launcher_icons   (crea tutte le misure iOS e Android)

File creati in assets/icon/:
- app_icon.png             1024×1024, icona completa (iOS e Android "classico")
- app_icon_dark.png        manubrio azzurro su trasparente (iOS 18, modalità scura:
                           lo sfondo scuro lo mette il sistema)
- app_icon_tinted.png      versione in scala di grigi (iOS 18, modalità "colorata")
- app_icon_background.png  solo il gradiente (sfondo dell'icona adattiva Android)
- app_icon_foreground.png  solo il manubrio, su trasparente (primo piano Android)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
# Si disegna a risoluzione doppia e poi si rimpicciolisce: i bordi
# (soprattutto quelli obliqui, dopo la rotazione) vengono più lisci.
SS = 2
BIG = SIZE * SS
ICON_DIR = Path(__file__).resolve().parent.parent / "assets" / "icon"

# Le forme del manubrio, in coordinate 1024×1024 *prima* della rotazione:
# (x, y, larghezza, altezza, raggio degli angoli).
DUMBBELL = [
    (300, 484, 424, 56, 28),   # barra
    (178, 467, 44, 90, 16),    # tappo sinistro
    (802, 467, 44, 90, 16),    # tappo destro
    (212, 387, 62, 250, 24),   # disco piccolo sinistro
    (750, 387, 62, 250, 24),   # disco piccolo destro
    (284, 347, 80, 330, 30),   # disco grande sinistro
    (660, 347, 80, 330, 30),   # disco grande destro
]
TOP, BOTTOM = 347, 677        # dove inizia e finisce il gradiente del manubrio
ANGLE = 35                    # gradi, in senso antiorario
SCALE = 0.86                  # quanto è grande il manubrio nell'icona completa

# Le tre varianti del canvas: (sfondo basso-sinistra, sfondo alto-destra),
# (manubrio sopra, manubrio sotto), (colore ombra, opacità ombra).
LIGHT = dict(bg=("#04333D", "#1C8A92"), fg=("#FFFFFF", "#DDF0EF"), shadow=("#021C22", 0.35))
DARK = dict(bg=("#091416", "#16292D"), fg=("#56C8CE", "#178790"), shadow=("#000000", 0.5))
TINTED = dict(bg=("#000000", "#141414"), fg=("#FFFFFF", "#8C8C8C"), shadow=("#000000", 0.5))


def rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t: float):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def background(colors) -> Image.Image:
    """Gradiente diagonale: primo colore in basso a sinistra, secondo in alto a destra."""
    start, end = rgb(colors[0]), rgb(colors[1])
    small = 256  # calcolato in piccolo e ingrandito: è una sfumatura, resta liscia
    img = Image.new("RGB", (small, small))
    px = img.load()
    for y in range(small):
        for x in range(small):
            t = (x + (small - 1 - y)) / (2 * (small - 1))
            px[x, y] = mix(start, end, t)
    return img.resize((SIZE, SIZE), Image.BICUBIC)


def dumbbell_layer(variant: dict, scale: float) -> Image.Image:
    """Il manubrio (con ombra) su sfondo trasparente, ruotato e centrato."""
    # 1) La sagoma: un'immagine in bianco e nero con le forme piene.
    mask = Image.new("L", (BIG, BIG), 0)
    draw = ImageDraw.Draw(mask)
    for x, y, w, h, r in DUMBBELL:
        draw.rounded_rectangle(
            [x * SS, y * SS, (x + w) * SS - 1, (y + h) * SS - 1], radius=r * SS, fill=255
        )

    # 2) Il colore: gradiente verticale dall'alto al basso del manubrio.
    top, bottom = rgb(variant["fg"][0]), rgb(variant["fg"][1])
    column = Image.new("RGB", (1, BIG))
    for y in range(BIG):
        t = min(max((y / SS - TOP) / (BOTTOM - TOP), 0), 1)
        column.putpixel((0, y), mix(top, bottom, t))
    shape = column.resize((BIG, BIG)).convert("RGBA")
    shape.putalpha(mask)

    # 3) L'ombra: la stessa sagoma, colorata, spostata in basso e sfocata.
    color, opacity = variant["shadow"]
    shadow = Image.new("RGBA", (BIG, BIG), rgb(color) + (0,))
    shadow.putalpha(mask.point(lambda a: round(a * opacity)))
    shadow = shadow.transform(
        shadow.size, Image.AFFINE, (1, 0, 0, 0, 1, -18 * SS)  # 18 px più in basso
    ).filter(ImageFilter.GaussianBlur(22 * SS))

    layer = Image.new("RGBA", (BIG, BIG), (0, 0, 0, 0))
    layer.alpha_composite(shadow)
    layer.alpha_composite(shape)

    # 4) Rotazione attorno al centro, poi rimpicciolimento e centratura.
    layer = layer.rotate(ANGLE, resample=Image.BICUBIC)
    side = round(SIZE * scale)
    layer = layer.resize((side, side), Image.LANCZOS)
    if side >= SIZE:  # più grande dell'icona: si tiene solo il centro (i bordi sono vuoti)
        cut = (side - SIZE) // 2
        return layer.crop((cut, cut, cut + SIZE, cut + SIZE))
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(layer, ((SIZE - side) // 2, (SIZE - side) // 2))
    return out


def full_icon(variant: dict) -> Image.Image:
    icon = background(variant["bg"]).convert("RGBA")
    icon.alpha_composite(dumbbell_layer(variant, SCALE))
    return icon


def main() -> None:
    # Icona principale: iOS non vuole trasparenze, quindi la salviamo in RGB.
    full_icon(LIGHT).convert("RGB").save(ICON_DIR / "app_icon.png")

    # iOS 18, modalità scura: solo il manubrio, lo sfondo lo disegna il sistema.
    dumbbell_layer(DARK, SCALE).save(ICON_DIR / "app_icon_dark.png")

    # iOS 18, modalità "colorata": in grigi, il sistema la ricolora.
    full_icon(TINTED).convert("L").convert("RGB").save(ICON_DIR / "app_icon_tinted.png")

    # Android adattiva: il telefono ritaglia l'icona (cerchio, goccia...).
    # flutter_launcher_icons aggiunge un margine del 16% per lato, quindi qui
    # il manubrio è più grande; alla fine resta dentro la "zona sicura"
    # (il cerchio centrale che nessun ritaglio taglia).
    background(LIGHT["bg"]).save(ICON_DIR / "app_icon_background.png")
    dumbbell_layer(LIGHT, 1.15).save(ICON_DIR / "app_icon_foreground.png")
    print("Icone generate in", ICON_DIR)


if __name__ == "__main__":
    main()
