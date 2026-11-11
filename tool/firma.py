"""Firma un APK di Transcrify con la chiave di rilascio e la sua storia (APK Signature Scheme v3, rotazione).

Perché (11 nov): sul telefono c'è Transcrify firmata con la chiave di debug. Un APK firmato solo con la chiave di
rilascio non si installerebbe sopra (firme diverse: bisognerebbe disinstallare e perdere i dati). Con la rotazione
della chiave (v3, minSdk 31) l'APK porta la «storia» debug → rilascio: Android lo accetta come aggiornamento e i dati
restano. Da qui in poi OGNI build da installare sul telefono (anche quelle di debug) va firmata così.

Uso (dalla cartella del progetto):
    flutter build apk --release --split-per-abi
    python tool/firma.py build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
    flutter build apk --debug
    python tool/firma.py build/app/outputs/flutter-apk/app-debug.apk

La storia (lineage) si crea la prima volta e sta accanto alla chiave di rilascio, fuori dal repo
(`transcrify-lineage.bin`). Le password si leggono da android/key.properties e passano ad apksigner per variabile
d'ambiente: non si stampano mai.
"""

import os
import subprocess
import sys
from pathlib import Path

RADICE = Path(__file__).resolve().parent.parent
SDK = Path(os.environ.get("ANDROID_HOME", Path.home() / "AppData/Local/Android/Sdk"))
APKSIGNER = SDK / "build-tools/36.0.0" / ("apksigner.bat" if os.name == "nt" else "apksigner")
JAVA = Path(os.environ.get("JAVA_HOME", "C:/Program Files/Android/Android Studio/jbr"))

# La chiave di debug di Android (quella con cui è firmata l'app che c'è sul telefono): password note a tutti.
DEBUG = {"file": Path.home() / ".android/debug.keystore", "alias": "androiddebugkey", "pass": "android"}


def proprieta():
    p = {}
    for riga in (RADICE / "android/key.properties").read_text(encoding="utf-8").splitlines():
        if "=" in riga and not riga.lstrip().startswith("#"):
            k, v = riga.split("=", 1)
            p[k.strip()] = v.strip()
    return p


def firmatario(file, alias, var_ks, var_key):
    return ["--ks", str(file), "--ks-key-alias", alias, "--ks-pass", f"env:{var_ks}", "--key-pass", f"env:{var_key}"]


def esegui(args, env):
    r = subprocess.run([str(APKSIGNER), *args], env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"apksigner non è riuscito:\n{r.stdout}\n{r.stderr}")
    return r.stdout


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    apk = Path(sys.argv[1]).resolve()
    k = proprieta()
    rilascio = Path(k["storeFile"])
    storia = rilascio.parent / "transcrify-lineage.bin"
    env = dict(os.environ, JAVA_HOME=str(JAVA), PATH=f"{JAVA / 'bin'}{os.pathsep}{os.environ['PATH']}")
    env.update(TR_DEBUG_KS=DEBUG["pass"], TR_DEBUG_KEY=DEBUG["pass"], TR_REL_KS=k["storePassword"], TR_REL_KEY=k["keyPassword"])
    vecchio = firmatario(DEBUG["file"], DEBUG["alias"], "TR_DEBUG_KS", "TR_DEBUG_KEY")
    nuovo = firmatario(rilascio, k["keyAlias"], "TR_REL_KS", "TR_REL_KEY")
    if not storia.exists():
        esegui(["rotate", "--out", str(storia), "--old-signer", *vecchio, "--new-signer", *nuovo], env)
        print(f"Storia della chiave creata: {storia}")
    # Il vecchio firmatario per v1/v2, il nuovo (con la storia) per v3: si installa sopra quella firmata in debug.
    esegui(["sign", *vecchio, "--next-signer", *nuovo, "--lineage", str(storia), "--rotation-min-sdk-version", "31", str(apk)], env)
    print(esegui(["verify", "-v", "--print-certs", str(apk)], env))


if __name__ == "__main__":
    main()
