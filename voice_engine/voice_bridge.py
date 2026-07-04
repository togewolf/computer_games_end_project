import os
import sys
import socket
import pyaudio
import numpy as np
import tensorflow as tf
from collections import deque
from tensorflow import keras

os.environ['CUDA_VISIBLE_DEVICES'] = '-1'

from parameters import CONTINUOUS_PARAMS, SAMPLE_RATE, SEQUENCE_LENGTH, DEFAULT_PARAMS
from spectrogram_utils import generate_mel_spectrogram

UDP_IP = "127.0.0.1"
UDP_PORT = 4242
MODEL_PATH = "model_nine_runes_framewise.keras"

# Exactly 11 classes (9 runes + 2 system classes).
CLASS_NAMES = ["unknown", "noise",
                     "igi", "vova", "rube", "pikat",
                    "zollzag", "bumbo", "noxo", "trodu", "pringo"]

KEYWORD_TO_EFFECT = {
    "igi": "fire",
    "vova": "water",
    "rube": "nature",
    "pikat": "light",
    "zollzag": "target",
    "bumbo": "projectile",
    "noxo": "slow",
    "trodu": "fast",
    "pringo": "fastest"
}


FORMAT = pyaudio.paInt16
CHANNELS = 1
CHUNK = CONTINUOUS_PARAMS["step_chunk_size"]
THRESHOLD = CONTINUOUS_PARAMS["confidence_threshold"]
SMOOTHING_FRAMES = CONTINUOUS_PARAMS["smoothing_frames"]
COOLDOWN_TIME = CONTINUOUS_PARAMS["cooldown_per_rune_seconds"]


def normalize_audio(audio_buffer, threshold=0.002):
    rms = np.sqrt(np.mean(audio_buffer ** 2))
    if rms > threshold:
        max_val = np.max(np.abs(audio_buffer))
        if max_val > 0: return (audio_buffer / max_val) * 0.8
    return audio_buffer


def start_bridge():
    print("Loading Speech Engine...")
    model = keras.models.load_model(MODEL_PATH)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    p = pyaudio.PyAudio()
    stream = p.open(format=FORMAT, channels=CHANNELS, rate=SAMPLE_RATE, input=True, frames_per_buffer=CHUNK)

    audio_buffer = np.zeros(SEQUENCE_LENGTH, dtype=np.float32)
    rune_cooldowns = {rune: 0.0 for rune in CLASS_NAMES}
    step_time_seconds = CHUNK / SAMPLE_RATE
    prob_history = deque(maxlen=SMOOTHING_FRAMES)

    ignore_indices = [0, 1]  # indices for "unknown" and "noise"

    print(f"VOICE BRIDGE ACTIVE on UDP {UDP_PORT}")

    try:
        while True:
            for rune in rune_cooldowns:
                if rune_cooldowns[rune] > 0:
                    rune_cooldowns[rune] -= step_time_seconds

            data = stream.read(CHUNK, exception_on_overflow=False)
            new_audio = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0
            audio_buffer = np.roll(audio_buffer, -CHUNK)
            audio_buffer[-CHUNK:] = new_audio

            processed_audio = normalize_audio(audio_buffer)
            input_tensor = tf.expand_dims(tf.convert_to_tensor(processed_audio, dtype=tf.float32), 0)
            spec = generate_mel_spectrogram(input_tensor, DEFAULT_PARAMS["crnn"], training=False)

            raw_predictions = model.predict(spec, verbose=0)[0]

            t_steps = raw_predictions.shape[0]
            center_probs = np.mean(raw_predictions[int(t_steps * 0.35):int(t_steps * 0.65), :], axis=0)

            prob_history.append(center_probs)
            if len(prob_history) < SMOOTHING_FRAMES: continue

            smoothed_probs = np.mean(prob_history, axis=0)
            rune_probs = np.copy(smoothed_probs)
            for idx in ignore_indices: rune_probs[idx] = 0.0

            best_rune_idx = np.argmax(rune_probs)
            best_rune_confidence = rune_probs[best_rune_idx]
            predicted_rune = CLASS_NAMES[best_rune_idx]

            # LIVE TELEMETRY UI
            top_3_indices = np.argsort(rune_probs)[-3:][::-1]
            debug_str = " | ".join([
                f"{CLASS_NAMES[idx].upper():>8}: {rune_probs[idx] * 100:>5.1f}%"
                for idx in top_3_indices
            ])
            sys.stdout.write(f"\r👁️  MIC: {debug_str}   ")
            sys.stdout.flush()

            # CASTING LOGIC
            if best_rune_confidence > THRESHOLD and rune_cooldowns[predicted_rune] <= 0:
                rune_cooldowns[predicted_rune] = COOLDOWN_TIME

                if predicted_rune in KEYWORD_TO_EFFECT:
                    effect = KEYWORD_TO_EFFECT[predicted_rune]

                    sys.stdout.write(
                        f"\nRune detected: [ {predicted_rune.upper()} ] -> {effect} (Conf: {best_rune_confidence * 100:.1f}%)\n")
                    sys.stdout.flush()

                    # SEND TO GODOT
                    sock.sendto(effect.encode('utf-8'), (UDP_IP, UDP_PORT))

    except KeyboardInterrupt:
        print("\nClosing Bridge...")
    finally:
        stream.stop_stream()
        stream.close()
        p.terminate()


if __name__ == "__main__":
    start_bridge()