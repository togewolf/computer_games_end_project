# spectrogram_utils.py
import tensorflow as tf
from parameters import SAMPLE_RATE


def generate_mel_spectrogram(waveform, params, training=False):
    # 1. Standard STFT
    spectrogram = tf.signal.stft(waveform, frame_length=params["frame_length"], frame_step=params["frame_step"])
    spectrogram = tf.abs(spectrogram)

    # 2. Convert to Mel-Spectrogram
    num_spectrogram_bins = spectrogram.shape[-1]
    num_mel_bins = 40

    linear_to_mel_weight_matrix = tf.signal.linear_to_mel_weight_matrix(
        num_mel_bins, num_spectrogram_bins, SAMPLE_RATE,
        lower_edge_hertz=80.0, upper_edge_hertz=SAMPLE_RATE / 2
    )

    mel_spectrogram = tf.tensordot(spectrogram, linear_to_mel_weight_matrix, 1)
    mel_spectrogram.set_shape(spectrogram.shape[:-1].concatenate(linear_to_mel_weight_matrix.shape[-1:]))
    log_mel_spectrogram = tf.math.log(mel_spectrogram + 1e-6)
    spec = tf.expand_dims(log_mel_spectrogram, -1)

    # --- SPECAUGMENT ---
    if training:
        # Because we call dataset.batch() BEFORE dataset.map(), the 'spec'
        # tensor is 4D: [batch_size, time_steps, freq_bins, channels]
        time_steps = tf.shape(spec)[1]
        freq_bins = tf.shape(spec)[2]

        # 1. Time Masking (mask up to ~16% of the time steps)
        max_t_mask = tf.maximum(1, time_steps // 6)
        t_mask_width = tf.random.uniform([], 0, max_t_mask, dtype=tf.int32)
        t0 = tf.random.uniform([], 0, time_steps - t_mask_width, dtype=tf.int32)

        # Create a 1D mask
        t_mask_1d = tf.concat([
            tf.ones([t0], dtype=tf.float32),
            tf.zeros([t_mask_width], dtype=tf.float32),
            tf.ones([time_steps - t0 - t_mask_width], dtype=tf.float32)
        ], axis=0)

        # Reshape to [1, time_steps, 1, 1] so it broadcasts across the whole batch
        t_mask = tf.reshape(t_mask_1d, [1, time_steps, 1, 1])
        spec = spec * t_mask

        # 2. Frequency Masking (mask up to 20% of the frequency bands)
        max_f_mask = tf.maximum(1, freq_bins // 5)
        f_mask_width = tf.random.uniform([], 0, max_f_mask, dtype=tf.int32)
        f0 = tf.random.uniform([], 0, freq_bins - f_mask_width, dtype=tf.int32)

        # Create a 1D mask
        f_mask_1d = tf.concat([
            tf.ones([f0], dtype=tf.float32),
            tf.zeros([f_mask_width], dtype=tf.float32),
            tf.ones([freq_bins - f0 - f_mask_width], dtype=tf.float32)
        ], axis=0)

        # Reshape to [1, 1, freq_bins, 1] so it broadcasts across the whole batch
        f_mask = tf.reshape(f_mask_1d, [1, 1, freq_bins, 1])
        spec = spec * f_mask

    return spec