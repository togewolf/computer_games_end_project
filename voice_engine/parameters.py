import numpy as np
import os

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

# --- CORE AUDIO SETTINGS ---
SAMPLE_RATE = 16000
SAMPLE_DURATION = 1.4
SEQUENCE_LENGTH = int(SAMPLE_RATE * SAMPLE_DURATION)

# --- CRNN PARAMETERS (Only the ones needed for inference) ---
DEFAULT_PARAMS = {
    "crnn": {
        "model_type": "crnn",
        "frame_length": 255,
        "frame_step": 128,
        "conv_filters": [64, 128],
        "dense_units": 128,
        "dropout_rate": 0.4,
        "conv_dropout": 0.2,
        "learning_rate": 0.0005,
        "batch_size": 64,
    }
}

# --- LIVE TEST SETTINGS ---
CONTINUOUS_PARAMS = {
    "step_chunk_size": 800,        # Update prediction every 0.05 seconds
    "smoothing_frames": 4,         # Average the last n predictions
    "confidence_threshold": 0.7,
    "cooldown_per_rune_seconds": 1.5
}