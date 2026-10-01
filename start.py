"""Avvia gli script Python di RegulArt e, se disponibile, lo sketch Processing."""
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))


def main():
    procs = [subprocess.Popen([sys.executable, os.path.join(ROOT, "python", script)])
             for script in ("msg.py", "mic.py")]

    #processing-java è l'interfaccia a riga di comando di Processing
    #(su macOS si installa da Tools > Install "processing-java")
    processing = shutil.which("processing-java")
    if processing:
        procs.append(subprocess.Popen([processing, "--sketch=" + os.path.join(ROOT, "RegulArt"), "--run"]))
    else:
        print("processing-java not found: open RegulArt/RegulArt.pde in Processing and press Run")

    try:
        #se uno dei processi termina, chiudiamo anche gli altri
        while all(p.poll() is None for p in procs):
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        for p in procs:
            if p.poll() is None:
                p.terminate()
        for p in procs:
            p.wait()


if __name__ == "__main__":
    main()
