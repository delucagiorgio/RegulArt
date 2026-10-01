import argparse
from collections import deque

import numpy as np
import pyaudio
from scipy.signal import butter, lfilter
from pythonosc import udp_client


# Constants
FORMAT = pyaudio.paFloat32
CHANNELS = 1
RATE = 44100
CHUNK = 2048
RECORD_SECONDS = 0.1
name_out = "/soundRepetition"

# Analisi degli onset (spectral flux)
N_FFT = 1024
HOP = 512
# Numero di valori dell'inviluppo degli onset al secondo
ENV_RATE = RATE / HOP
# Durata della finestra su cui si cerca la periodicità
ENV_SECONDS = 6
# Intervallo di tempo (in BPM) considerato regolare
MIN_BPM = 40
MAX_BPM = 200
# Lunghezza (in frame, ~12 ms l'uno) dello smoothing dell'inviluppo: rende la misura
# tollerante a piccole imprecisioni ritmiche
SMOOTH_FRAMES = 9
# Variabilità minima dell'inviluppo: sotto questa soglia non ci sono onset
# (es. silenzio o suono continuo) e la periodicità non è significativa
min_envelope_std = 2.0

#Thresholds (con isteresi, per evitare cambi di stato continui)
regular_on_thresh = 0.5
regular_off_thresh = 0.35

# Normalizzazione del volume: il picco di riferimento decade nel tempo
peak_decay = 0.99
min_peak = 1e-4


#Filter definition
def butter_bandpass(lowcut=40, highcut=2000, fs=RATE, order=2):
    nyq = 0.5 * fs
    low = lowcut / nyq
    high = highcut / nyq
    b, a = butter(order, [low, high], btype='band')
    return b, a


# Performing RMS
def root_mean_square(wavedata):
    return float(np.nan_to_num(np.sqrt(np.mean(wavedata ** 2))))


# Periodicità dell'inviluppo: massimo picco locale dell'autocorrelazione normalizzata
# tra i lag corrispondenti a MAX_BPM e MIN_BPM (0 = nessuna periodicità, 1 = periodico)
def periodicity(envelope):
    min_lag = int(ENV_RATE * 60 / MAX_BPM)
    max_lag = int(ENV_RATE * 60 / MIN_BPM)
    x = np.asarray(envelope, dtype=float)
    if len(x) <= max_lag + 1 or np.std(x) < min_envelope_std:
        return 0.0
    kernel = np.hanning(SMOOTH_FRAMES)
    x = np.convolve(x - np.mean(x), kernel / kernel.sum(), mode='same')
    energy = np.dot(x, x)
    if energy == 0:
        return 0.0

    n = len(x)
    ac = np.correlate(x, x, mode='full')[n - 1:] / energy
    #normalizzazione non distorta: compensa il minor numero di campioni sui lag lunghi
    ac = ac * n / (n - np.arange(n))
    lags = np.arange(min_lag, max_lag + 1)
    peaks = lags[(ac[lags] > ac[lags - 1]) & (ac[lags] >= ac[lags + 1])]
    if len(peaks) == 0:
        return 0.0
    return float(np.max(ac[peaks]))


class RegularityDetector():
    def __init__(self):
        self.bp_b, self.bp_a = butter_bandpass()
        #stato del filtro, mantenuto tra un blocco e il successivo
        self.zi = np.zeros(max(len(self.bp_a), len(self.bp_b)) - 1)
        self.window = np.hanning(N_FFT)
        #campioni non ancora analizzati
        self.buffer = np.zeros(0)
        self.prev_mag = None
        #inviluppo degli onset (spectral flux) degli ultimi ENV_SECONDS secondi
        self.envelope = deque(maxlen=int(ENV_SECONDS * ENV_RATE))
        self.regular = False
        self.peak = min_peak

    def update_envelope(self, data):
        filtered, self.zi = lfilter(self.bp_b, self.bp_a, data, zi=self.zi)
        self.buffer = np.concatenate([self.buffer, filtered])
        while len(self.buffer) >= N_FFT:
            mag = np.log1p(100 * np.abs(np.fft.rfft(self.buffer[:N_FFT] * self.window)))
            if self.prev_mag is not None:
                #spectral flux: somma degli incrementi positivi di energia tra frame consecutivi
                self.envelope.append(np.sum(np.maximum(mag - self.prev_mag, 0)))
            self.prev_mag = mag
            self.buffer = self.buffer[HOP:]

    #Restituisce lo stato di regolarità e il volume normalizzato (0,1)
    def process(self, data):
        self.update_envelope(data)

        score = periodicity(self.envelope)
        self.regular = score > (regular_off_thresh if self.regular else regular_on_thresh)

        rms = root_mean_square(data)
        self.peak = max(rms, self.peak * peak_decay, min_peak)
        return self.regular, rms / self.peak


def main():
    parser = argparse.ArgumentParser(description="Analisi audio dal microfono per RegulArt")
    parser.add_argument("--ip", default="127.0.0.1", help="indirizzo di Processing")
    parser.add_argument("--port", type=int, default=58121, help="porta OSC di Processing")
    args = parser.parse_args()

    client = udp_client.SimpleUDPClient(args.ip, args.port)
    detector = RegularityDetector()
    chunks_per_step = max(1, int(RATE / CHUNK * RECORD_SECONDS))

    audio = pyaudio.PyAudio()
    # start Recording
    stream = audio.open(format=FORMAT, channels=CHANNELS,
                        rate=RATE, input=True,
                        frames_per_buffer=CHUNK)
    print("recording...")

    try:
        while True:
            data = np.concatenate([
                np.frombuffer(stream.read(CHUNK, exception_on_overflow=False), dtype=np.float32)
                for _ in range(chunks_per_step)])
            regular, volume = detector.process(data)
            client.send_message(name_out, [int(regular), float(volume)])
    except KeyboardInterrupt:
        pass
    finally:
        stream.stop_stream()
        stream.close()
        audio.terminate()


if __name__ == "__main__":
    main()
