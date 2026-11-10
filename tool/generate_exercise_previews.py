"""Genera le anteprime SVG degli esercizi (stile "badge colorato").

Uso:  python tool/generate_exercise_previews.py [percorso_foglio_anteprime.html]

Ogni esercizio è un omino bianco su un quadrato arrotondato colorato.
Il colore dice il gruppo muscolare (o la fase: riscaldamento).
Le pose sono polilinee in un riquadro 120×120 (x verso destra, y verso il basso).
Per cambiare lo stile di TUTTE le immagini basta modificare le costanti qui sotto
e rilanciare lo script: i file in assets/images/exercises/ vengono riscritti.
"""
import math
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "images", "exercises")

# --- Stile ---------------------------------------------------------------
SIZE = 120
RADIUS = 26
BODY_WIDTH = 7
HEAD_RADIUS = 7.5
EQUIP_WIDTH = 5
EQUIP_OPACITY = 0.55

COLORS = {
    "gambe": "#0A84FF",
    "petto": "#FF2D55",
    "schiena": "#5E5CE6",
    "spalle": "#BF5AF2",
    "braccia": "#FF9F0A",
    "core": "#34C759",
    "riscaldamento": "#FF6B3D",
}

MAT = "16,104 104,104"


def front_legs():
    return ["60,62 53,100", "60,62 67,100"]


STANDING = ["60,36 60,64", "60,64 61,82 60,100 68,100"]

# Macchina vista di lato: schienale, seduta e montante (chi è seduto guarda a destra).
SEAT = ["38,40 38,86", "38,86 62,86", "52,86 52,103"]
SEATED = ["46,80 44,50", "46,80 68,80 68,100 76,100"]


def arc(cx, cy, r, start, end, steps=10):
    """Un arco di cerchio come polilinea (gradi: 0 = destra, 90 = giù)."""
    pts = []
    for i in range(steps + 1):
        a = math.radians(start + (end - start) * i / steps)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)

# --- Pose ----------------------------------------------------------------
# body: polilinee del corpo; head: centro della testa;
# equip: polilinee degli attrezzi; circles: (x, y, r) di attrezzi tondi.
POSES = {
    # Riscaldamento
    "cardio_riscaldamento": dict(group="riscaldamento", head=(61, 24),
        body=["60,36 58,64", "58,64 66,82 70,99 78,99", "58,64 52,82 44,97", "60,38 66,50 74,56", "60,38 52,50 47,60"],
        equip=["24,104 96,104", "92,104 88,58 78,58"]),
    "dislocazioni_bastone": dict(group="riscaldamento", head=(60, 23),
        body=["60,35 60,62", *front_legs(), "60,38 46,26 38,14", "60,38 74,26 82,14"],
        equip=["22,13 98,13"]),
    "rotazioni_busto": dict(group="riscaldamento", head=(60, 23),
        body=["60,35 60,62", *front_legs(), "60,38 47,45 40,35", "60,38 73,45 80,35"],
        equip=["26,34 94,34", "40,52 50,57 60,59 70,57 79,52", "79,52 72,51", "79,52 77,59"]),
    "inclinazioni_laterali": dict(group="riscaldamento", head=(45, 26),
        body=["60,62 50,37", *front_legs(), "50,39 40,24", "50,39 62,18"],
        equip=["30,27 74,13"]),
    "good_morning_bastone": dict(group="riscaldamento", head=(91, 43),
        body=["52,62 80,49", "52,62 56,82 56,100 64,100", "80,50 76,42 82,44"],
        circles=[(81, 43, 4.5)]),
    "squat_lento": dict(group="riscaldamento", head=(59, 35),
        body=["48,70 56,46", "48,70 70,72 64,100 76,100", "56,48 70,56 81,56"],
        equip=["85,40 85,103"]),
    "gatto_cammello": dict(group="riscaldamento", head=(93, 78),
        body=["46,72 53,63 64,59 75,63 82,72", "82,72 84,100", "46,72 46,100 26,100"],
        equip=[MAT]),
    "ponte_glutei": dict(group="riscaldamento", head=(18, 95),
        body=["28,97 56,82 76,72", "76,72 80,100 88,100", "28,98 48,100"],
        equip=[MAT]),

    # Pesi
    "leg_press": dict(group="gambe", head=(25, 52),
        body=["31,63 48,87", "48,87 68,62 84,72", "31,65 41,79 50,88"],
        equip=["24,58 44,94", "44,94 64,94", "80,58 93,80"]),
    "chest_press": dict(group="petto", head=(45, 38),
        body=["46,80 44,50", "46,80 68,80 68,100 76,100", "44,52 60,56 76,52"],
        equip=["38,40 38,86", "38,86 62,86", "52,86 52,103", "79,45 79,59"]),
    "lat_machine": dict(group="schiena", head=(45, 38),
        body=["50,78 46,50", "50,78 72,76 72,100 82,100", "46,51 50,35 54,21"],
        equip=["54,6 54,20", "43,20 65,20", "36,84 62,84", "49,84 49,103", "64,68 80,68"]),
    "leg_curl_seduto": dict(group="gambe", head=(44, 38),
        body=["46,78 44,50", "46,78 74,78 70,99", "44,52 50,66 56,75"],
        equip=["38,40 38,84", "38,84 66,84", "52,84 52,103", "60,70 78,70"],
        circles=[(78, 96, 5)]),
    "shoulder_press_macchina": dict(group="spalle", head=(45, 38),
        body=["46,80 44,50", "46,80 68,80 68,100 76,100", "44,52 56,40 53,23"],
        equip=["38,40 38,86", "38,86 62,86", "52,86 52,103", "46,22 61,22"]),
    "curl_manubri": dict(group="braccia", head=(60, 24),
        body=[*STANDING, "60,38 65,53 75,41"],
        equip=["69,41 81,41", "69,36 69,46", "81,36 81,46"]),
    "plank": dict(group="core", head=(92, 72),
        body=["20,99 25,95 52,85 81,78", "81,79 81,99 95,99"],
        equip=[MAT]),
    "crunch_macchina": dict(group="core", head=(69, 46),
        body=["46,80 49,63 60,51", "46,80 70,80 70,100 78,100", "59,53 67,64 77,62"],
        equip=["38,86 62,86", "50,86 50,103", "38,86 36,52"]),
    "pulley_basso": dict(group="schiena", head=(40, 44),
        body=["38,84 40,56", "38,84 62,74 82,84", "40,58 31,70 49,72"],
        equip=["22,90 58,90", "28,90 28,103", "52,90 52,103", "87,72 87,98", "50,72 87,84"]),
    "hip_thrust_macchina": dict(group="gambe", head=(25, 59),
        body=["34,66 62,66", "62,66 81,68 81,100 89,100", "34,68 46,74"],
        equip=["14,72 38,72", "26,72 26,103", "52,58 72,58", "62,58 84,44"]),
    "leg_extension": dict(group="gambe", head=(44, 38),
        body=["46,78 44,50", "46,78 70,78 93,70", "44,52 50,66 56,75"],
        equip=["38,40 38,84", "38,84 66,84", "52,84 52,103"],
        circles=[(90, 79, 5)]),
    "alzate_laterali_manubri": dict(group="spalle", head=(60, 23),
        body=["60,35 60,62", *front_legs(), "60,38 43,40 28,37", "60,38 77,40 92,37"],
        equip=["24,30 24,44", "96,30 96,44"]),
    "pushdown_cavo": dict(group="braccia", head=(61, 24),
        body=["60,36 58,64", "58,64 59,82 58,100 66,100", "60,38 60,53 72,63"],
        equip=["73,62 84,12"],
        circles=[(85, 10, 4.5)]),

    # Addominali
    "plank_laterale": dict(group="core", head=(90, 58),
        body=["22,100 52,84 80,66", "80,67 79,99 93,99", "80,66 86,42"],
        equip=[MAT]),
    "leg_raise": dict(group="core", head=(19, 94),
        body=["28,97 58,97", "58,97 67,42", "30,98 50,100"],
        equip=[MAT]),
    "heel_touch": dict(group="core", head=(25, 84),
        body=["33,89 58,97", "58,97 74,77 84,98", "35,91 58,96 77,94"],
        equip=[MAT]),

    # --- Fase 2 · Push/Pull/Legs -----------------------------------------
    # Riscaldamento
    "rotazioni_braccia": dict(group="riscaldamento", head=(60, 23),
        body=["60,35 60,62", *front_legs(), "60,38 28,38", "60,38 92,38"],
        equip=[arc(24, 38, 11, 200, 470), arc(96, 38, 11, 70, 340)]),
    "piegamenti_rialzo": dict(group="riscaldamento", head=(33, 55),
        body=["96,99 42,64", "96,99 104,99", "43,65 52,73 40,78"],
        equip=["18,80 50,80", "22,80 22,103", "46,80 46,103"]),
    "tirate_scapolari": dict(group="riscaldamento", head=(45, 38),
        body=["50,78 46,50", "50,78 72,76 72,100 82,100", "46,51 52,18"],
        equip=["54,6 54,17", "41,17 65,17", "36,84 62,84", "49,84 49,103",
               "64,68 80,68", "70,28 70,46", "64,40 70,46 76,40"]),
    "slanci_gamba": dict(group="riscaldamento", head=(60, 23),
        body=["60,35 60,64", "60,64 61,82 60,100 68,100", "60,64 76,80 86,94", "60,40 46,50 34,48"],
        equip=["30,30 30,103", arc(60, 64, 36, 20, 110)]),

    # Pesi · Push
    "pec_deck": dict(group="petto", head=(60, 24),
        body=["60,36 60,66", "60,66 50,74 50,100", "60,66 70,74 70,100",
              "60,40 38,46 38,30", "60,40 82,46 82,30"],
        equip=["32,22 32,50", "88,22 88,50", "42,70 78,70"]),
    "macchina_tricipiti": dict(group="braccia", head=(45, 38),
        body=[*SEATED, "44,52 64,58 78,78"],
        equip=[*SEAT, "50,64 68,66"], circles=[(80, 80, 4.5)]),
    "french_press_manubrio": dict(group="braccia", head=(48, 40),
        body=["46,80 46,52", "46,80 68,80 68,100 76,100", "47,53 56,22 40,26"],
        equip=["38,56 38,86", "38,86 62,86", "52,86 52,103", "36,18 36,34", "30,18 42,18", "30,34 42,34"]),

    # Pesi · Pull
    "rematore_appoggio_petto": dict(group="schiena", head=(52, 38),
        body=["46,80 50,50", "46,80 68,80 68,100 76,100", "50,53 34,62 60,60"],
        equip=["38,86 62,86", "52,86 52,103", "62,42 62,74", "68,52 68,68"]),
    "reverse_pec_deck": dict(group="spalle", head=(60, 24),
        body=["60,36 60,66", "60,66 50,74 50,100", "60,66 70,74 70,100", "60,40 16,42", "60,40 104,42"],
        equip=["12,34 12,50", "108,34 108,50", "42,70 78,70"]),
    "iperestensioni": dict(group="schiena", head=(26, 38),
        body=["92,98 60,70", "60,70 34,46", "92,98 100,94", "40,52 48,52 46,60"],
        equip=["52,80 68,64", "62,74 74,103", "86,103 104,92"]),
    "curl_macchina": dict(group="braccia", head=(45, 38),
        body=[*SEATED, "44,52 70,66 74,44"],
        equip=[*SEAT, "50,62 76,76"], circles=[(75, 40, 4.5)]),

    # Pesi · Legs
    "hack_squat": dict(group="gambe", head=(34, 30),
        body=["40,40 56,70", "56,70 80,62 84,94 92,94"],
        equip=["26,32 48,78", "20,16 64,104", "78,99 100,90"]),
    "adductor": dict(group="gambe", head=(60, 22),
        body=["60,34 60,62", "60,64 34,74 30,100", "60,64 86,74 90,100",
              "60,38 48,52 46,62", "60,38 72,52 74,62"],
        equip=["40,66 40,84", "80,66 80,84", "48,66 72,66"]),
    "abductor": dict(group="gambe", head=(60, 22),
        body=["60,34 60,62", "60,64 48,74 48,100", "60,64 72,74 72,100",
              "60,38 46,52 40,60", "60,38 74,52 80,60"],
        equip=["36,64 36,84", "84,64 84,84", "48,64 72,64"]),
    "calf_machine": dict(group="gambe", head=(60, 22),
        body=["60,34 60,64", "60,64 61,82 61,94 70,98", "60,38 70,46 72,34"],
        equip=["48,33 74,33", "80,26 80,103", "64,102 86,102"]),

}


def polyline(points, color, width, opacity=1.0):
    op = f' stroke-opacity="{opacity}"' if opacity != 1 else ""
    return (f'  <polyline points="{points}" stroke="{color}" stroke-width="{width}"{op} '
            'stroke-linecap="round" stroke-linejoin="round"/>\n')


def render(pose):
    bg = COLORS[pose["group"]]
    parts = [f'  <rect width="{SIZE}" height="{SIZE}" rx="{RADIUS}" fill="{bg}"/>\n']
    for p in pose.get("equip", []):
        parts.append(polyline(p, "#FFFFFF", EQUIP_WIDTH, EQUIP_OPACITY))
    for x, y, r in pose.get("circles", []):
        parts.append(f'  <circle cx="{x}" cy="{y}" r="{r}" fill="#FFFFFF" fill-opacity="{EQUIP_OPACITY}"/>\n')
    for p in pose["body"]:
        parts.append(polyline(p, "#FFFFFF", BODY_WIDTH))
    hx, hy = pose["head"]
    parts.append(f'  <circle cx="{hx}" cy="{hy}" r="{HEAD_RADIUS}" fill="#FFFFFF"/>\n')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
            f'viewBox="0 0 {SIZE} {SIZE}" fill="none">\n' + "".join(parts) + "</svg>\n")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet = []
    for exercise_id, pose in POSES.items():
        svg = render(pose)
        with open(os.path.join(OUT_DIR, exercise_id + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
        preview = svg.replace(f'width="{SIZE}" height="{SIZE}"', 'width="110" height="110"', 1)
        sheet.append('<figure style="margin:0;text-align:center;width:130px">' + preview
                     + f'<figcaption style="font:11px sans-serif">{exercise_id}</figcaption></figure>')
    print(f"{len(POSES)} anteprime scritte in {os.path.normpath(OUT_DIR)}")
    if len(sys.argv) > 1:
        with open(sys.argv[1], "w", encoding="utf-8") as f:
            f.write('<!doctype html><meta charset="utf-8"><body style="margin:12px">'
                    '<div style="display:flex;flex-wrap:wrap;gap:10px">' + "".join(sheet) + "</div></body>")


if __name__ == "__main__":
    main()
