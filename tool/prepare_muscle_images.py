"""Prepara le illustrazioni dei muscoli per l'app.

Uso:  python tool/prepare_muscle_images.py <cartella_originali>

Gli originali sono quadrati 1254×1254 con sfondo grigio uniforme (~#E2E2E2)
e si chiamano 1.webp, 2.webp… (vedi NAMES). Per ognuno lo script:
1. ritaglia sulla figura (stesso ritaglio per tutti, così le figure
   restano della stessa grandezza);
2. rende trasparente lo sfondo grigio con un "secchiello" che parte dai
   bordi: diventa trasparente solo il grigio collegato all'esterno, non le
   zone chiare dentro il corpo;
3. sfuma di poco il contorno, così non si vedono scalini;
4. salva assets/images/muscles/<nome>.webp (con trasparenza).
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

NAMES = {
    1: "petto", 2: "dorsali", 3: "femorali", 4: "spalle",
    5: "bicipiti", 6: "addome_obliqui", 7: "retto_addominale", 8: "quadricipiti",
    10: "tricipiti",  # la 9 era di nuovo i dorsali: scartata
    11: "glutei",
}
CROP = (352, 0, 898, 1254)   # la figura sta tra x 372 e 878 in tutte le immagini
TOLERANCE = 9                # quanto un pixel può scostarsi dal grigio di sfondo
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "images" / "muscles"


def background_mask(rgb: np.ndarray) -> np.ndarray:
    """True dove c'è sfondo collegato ai bordi dell'immagine."""
    h, w, _ = rgb.shape
    # Il colore di sfondo: la mediana degli angoli.
    corners = np.array([rgb[2, 2], rgb[2, -3], rgb[-3, 2], rgb[-3, -3]], dtype=int)
    bg = np.median(corners, axis=0)
    close = np.abs(rgb.astype(int) - bg).max(axis=2) <= TOLERANCE

    # Secchiello (ricerca in ampiezza) a partire da tutti i pixel del bordo.
    seen = np.zeros((h, w), dtype=bool)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if close[y, x] and not seen[y, x]:
                seen[y, x] = True
                queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and close[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def process(src: Path, name: str) -> None:
    im = Image.open(src).convert("RGB").crop(CROP)
    rgb = np.asarray(im)
    alpha = np.where(background_mask(rgb), 0, 255).astype(np.uint8)
    # Contorno morbido: sfoca appena la maschera, poi tieni pieno l'interno.
    soft = np.asarray(Image.fromarray(alpha).filter(ImageFilter.GaussianBlur(0.8)))
    alpha = soft
    out = Image.fromarray(np.dstack([rgb, alpha]), "RGBA")
    # Ritaglia via i bordi completamente trasparenti.
    out = out.crop(out.getchannel("A").getbbox())
    out.save(OUT_DIR / f"{name}.webp", "WEBP", quality=88, method=6)
    print(f"{name}.webp  {out.size}")


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src_dir = Path(sys.argv[1])
    for number, name in NAMES.items():
        process(src_dir / f"{number}.webp", name)


if __name__ == "__main__":
    main()
