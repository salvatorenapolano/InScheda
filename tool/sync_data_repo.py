"""Copia i dati dell'app nella cartella del repo pubblico myWorkout-data.

Uso:  python tool/sync_data_repo.py [cartella_repo_dati]
      (di default ../myWorkout-data, accanto a questo progetto)

Copia assets/data/*.json, assets/images/exercises/*.svg e
assets/images/muscles/* con gli stessi percorsi, e cancella dal repo dei dati
i file che nell'app non ci sono più. Poi nel repo dei dati basta:
    git add -A && git commit -m "Cosa è cambiato" && git push
e dall'app: cerchio del profilo → "Scarica gli ultimi dati".
"""
import os
import shutil
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
FOLDERS = ["assets/data", "assets/images/exercises", "assets/images/muscles"]


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "..", "myWorkout-data")
    target = os.path.normpath(target)
    if not os.path.isdir(target):
        sys.exit(f"Cartella non trovata: {target}")
    copied = removed = 0
    for folder in FOLDERS:
        src = os.path.join(ROOT, folder)
        dst = os.path.join(target, folder)
        os.makedirs(dst, exist_ok=True)
        names = set(os.listdir(src))
        for name in sorted(names):
            src_file = os.path.join(src, name)
            dst_file = os.path.join(dst, name)
            with open(src_file, "rb") as f:
                new = f.read()
            old = None
            if os.path.exists(dst_file):
                with open(dst_file, "rb") as f:
                    old = f.read()
            if new != old:
                shutil.copyfile(src_file, dst_file)
                copied += 1
        for name in os.listdir(dst):
            if name not in names:
                os.remove(os.path.join(dst, name))
                removed += 1
    print(f"{copied} file copiati, {removed} cancellati in {target}")


if __name__ == "__main__":
    main()
