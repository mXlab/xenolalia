"""Analyze encoder activation vectors from the Xenolalia autoencoder.

Runs the model N times in feedback-loop mode (each from a different random seed),
collects per-channel stats (min, max, avg) from the encoder bottleneck layer,
then analyses sparsity, amplitude, diversity, and inter/intra-run variation.

Goal: verify whether the vectors sent to the sonoscope Pd patch carry meaningful,
diverse information across different autoencoder generations.

Usage:
    python analyze_encoder.py                        # uses settings.json defaults
    python analyze_encoder.py -n 100 -s 8            # 100 runs, 8 steps each
    python analyze_encoder.py --vector max -o out/   # analyse the 'max' stat vector
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from scipy.spatial.distance import pdist
from sklearn.decomposition import PCA
from tqdm import tqdm

# ── CLI ────────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    description=__doc__,
)
parser.add_argument("-C", "--configuration-file", type=str,
                    default="XenoPi/settings.json",
                    help="Path to settings.json")
parser.add_argument("-M", "--model-directory", type=str, default="results",
                    help="Directory containing .hdf5 model files")
parser.add_argument("-n", "--n-experiments", type=int, default=50,
                    help="Number of independent feedback runs (different random seeds)")
parser.add_argument("-s", "--n-steps", type=int, default=None,
                    help="Feedback steps per run (default: n_feedback_steps from settings)")
parser.add_argument("--vector", type=str, default="avg",
                    choices=["min", "max", "avg"],
                    help="Which per-channel stat vector to analyse")
parser.add_argument("-o", "--output-dir", type=str, default="analysis",
                    help="Directory to save plots and text report")
parser.add_argument("--save-glyphs", type=str, default=None, metavar="DIR",
                    help="If set, save each glyph image + _code.json + _code_signature.json to this directory")
parser.add_argument("--feature-maps", action="store_true", default=False,
                    help="Save a grid image showing the mean 7×7 activation map per encoder channel")
parser.add_argument("--activation-maps", action="store_true", default=False,
                    help="Save a grid image showing the activation-maximisation result per channel "
                         "(gradient ascent from random noise — requires TensorFlow)")
parser.add_argument("--gradient-steps", type=int, default=300,
                    help="Gradient-ascent steps for --activation-maps")
parser.add_argument("--gradient-lr", type=float, default=0.05,
                    help="Learning rate for --activation-maps gradient ascent")
parser.add_argument("--sparsity-threshold", type=float, default=0.05,
                    help="Values below this are considered near-zero (sparsity)")
args = parser.parse_args()

# ── Load settings ──────────────────────────────────────────────────────────────

with open(args.configuration_file, "r") as f:
    settings = json.load(f)

model_name      = settings["model_name"]
encoder_layer   = settings["encoder_layer"]
use_conv        = settings["use_convolutional"]
n_steps         = args.n_steps if args.n_steps is not None else settings["n_feedback_steps"]

image_side = 28
image_dim  = image_side * image_side
input_shape = (1, image_side, image_side, 1) if use_conv else (1, image_dim)

print("Model     : {}".format(model_name))
print("Enc layer : {}".format(encoder_layer))
print("Conv      : {}".format(use_conv))
print("Steps/run : {}".format(n_steps))
print("Runs      : {}".format(args.n_experiments))
print("Vector    : {}".format(args.vector))

# ── Load model ─────────────────────────────────────────────────────────────────

from keras.models import Model, load_model  # noqa: E402 (after argparse)

model_file = "{}/{}.hdf5".format(args.model_directory, model_name)
print("\nLoading model: {}".format(model_file))
autoencoder = load_model(model_file, compile=False)
model = Model(
    inputs=autoencoder.input,
    outputs=[
        autoencoder.layers[encoder_layer].output,
        autoencoder.output,
    ]
)
# Infer encoder shape from a test prediction (Keras 3 removed layer.output_shape).
_test = np.zeros(input_shape, dtype=np.float32)
_enc, _ = model(_test, training=False)
encoder_shape = tuple(_enc.shape[1:])
print("Encoder output shape: {}".format(encoder_shape))

os.makedirs(args.output_dir, exist_ok=True)

# ── Helpers ────────────────────────────────────────────────────────────────────

def array_to_image(frame):
    """Convert model output array (1, H, W, 1) or (1, N) to grayscale PIL image."""
    if frame.ndim == 4:
        img = frame[0, :, :, 0]
    else:
        img = frame[0].reshape(image_side, image_side)
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(img, mode='L')


def _save_encoded_json(encoded, filepath, precision=4):
    """Save raw encoder activations as channel-major JSON (matches xeno_osc format, no normalization)."""
    arr = encoded.copy()
    if arr.ndim == 4:
        arr = arr[0]                        # (H, W, C)
        channels = np.round(np.transpose(arr, (2, 0, 1)), precision).tolist()
    else:
        channels = np.round(arr.flatten().astype(np.float32), precision).tolist()
    with open(filepath, "w") as f:
        json.dump(channels, f, indent=2)


def _save_code_signature(encoded, filepath, n_bins=40, precision=4):
    """Save compact signature JSON (matches xeno_osc format)."""
    arr = (encoded[0] if encoded.ndim == 4 else encoded).astype(np.float32)
    vmin, vmax = arr.min(), arr.max()
    if vmax > vmin:
        arr = (arr - vmin) / (vmax - vmin)
    def _r(v): return round(float(v), precision)
    if arr.ndim == 3:
        H, W, C = arr.shape
        spatial = arr.reshape(H * W, C)
        def _peak(ch_map):
            vmax = ch_map.max()
            rows, cols = np.where(ch_map == vmax)
            return [int(round(rows.mean())), int(round(cols.mean()))]
        peak_rc = [_peak(arr[:, :, c]) for c in range(C)]
        data = {
            "model": model_name,
            "encoder_layer": encoder_layer,
            "encoder_shape": list(arr.shape),
            "n_values": int(arr.size),
            "min":  [_r(v) for v in spatial.min(axis=0)],
            "max":  [_r(v) for v in spatial.max(axis=0)],
            "avg":  [_r(v) for v in spatial.mean(axis=0)],
            "std":  [_r(v) for v in spatial.std(axis=0)],
            "q25":  [_r(v) for v in np.percentile(spatial, 25, axis=0)],
            "q50":  [_r(v) for v in np.percentile(spatial, 50, axis=0)],
            "q75":  [_r(v) for v in np.percentile(spatial, 75, axis=0)],
            "peak": peak_rc,
        }
    else:
        flat = arr.flatten()
        bins = np.array_split(flat, n_bins)
        data = {
            "model": model_name,
            "encoder_layer": encoder_layer,
            "encoder_shape": list(arr.shape),
            "n_values": int(flat.size),
            "min":  [_r(b.min())  for b in bins],
            "max":  [_r(b.max())  for b in bins],
            "avg":  [_r(b.mean()) for b in bins],
            "std":  [_r(b.std())  for b in bins],
            "q25":  [_r(np.percentile(b, 25)) for b in bins],
            "q50":  [_r(np.percentile(b, 50)) for b in bins],
            "q75":  [_r(np.percentile(b, 75)) for b in bins],
        }
    with open(filepath, "w") as f:
        json.dump(data, f, indent=2)


def compute_signature(encoded):
    """Return (min_vec, max_vec, avg_vec) per channel, globally normalized to [0,1]."""
    arr = encoded[0] if encoded.ndim == 4 else encoded
    arr = arr.astype(np.float32)
    vmin, vmax = arr.min(), arr.max()
    if vmax > vmin:
        arr = (arr - vmin) / (vmax - vmin)
    if arr.ndim == 3:
        H, W, C = arr.shape
        spatial = arr.reshape(H * W, C)        # (H*W, C)
        return spatial.min(axis=0), spatial.max(axis=0), spatial.mean(axis=0)
    else:
        flat = arr.flatten()
        return np.array([flat.min()]), np.array([flat.max()]), np.array([flat.mean()])


def run_experiment(n, collect_frames=False):
    """Run one feedback loop from a random seed; return list of (min, max, avg) per step.
    If collect_frames is True, also return (frames, encodeds) lists for saving glyphs."""
    frame = np.random.random(input_shape).astype(np.float32)
    sigs = []
    for _ in range(n):
        encoded, frame = model.predict(frame, verbose=0)
        sigs.append(compute_signature(encoded))
    if collect_frames:
        return sigs, np.array(frame), np.array(encoded)
    return sigs

# ── Collect data ───────────────────────────────────────────────────────────────

save_glyphs   = args.save_glyphs is not None
feature_maps  = args.feature_maps
collect_frames = save_glyphs or feature_maps
if save_glyphs:
    os.makedirs(args.save_glyphs, exist_ok=True)

print("\nRunning experiments...")
all_runs     = []
all_frames   = [] if collect_frames else None
all_encodeds = [] if collect_frames else None
for i in tqdm(range(args.n_experiments)):
    if collect_frames:
        sigs, frame, encoded = run_experiment(n_steps, collect_frames=True)
        all_frames.append(frame)
        all_encodeds.append(encoded)
    else:
        sigs = run_experiment(n_steps)
    all_runs.append(sigs)

# ── Save glyphs ────────────────────────────────────────────────────────────────

if save_glyphs:
    print("\nSaving glyphs to {} ...".format(args.save_glyphs))
    for idx in range(len(all_frames)):
        name = "glyph_{:04d}".format(idx)
        array_to_image(all_frames[idx]).save(
            os.path.join(args.save_glyphs, name + ".png"))
        _save_encoded_json(all_encodeds[idx],
            os.path.join(args.save_glyphs, name + "_code.json"))
        _save_code_signature(all_encodeds[idx],
            os.path.join(args.save_glyphs, name + "_code_signature.json"))
    print("Saved {} glyphs.".format(len(all_frames)))

# ── Feature maps ───────────────────────────────────────────────────────────────

if feature_maps:
    print("\nComputing feature maps ...")
    R_fm = len(all_encodeds)
    C_fm = encoder_shape[-1]
    enc_H, enc_W = encoder_shape[0], encoder_shape[1]

    # Accumulate mean 7×7 activation map per channel (globally normalised per run).
    chan_maps = np.zeros((C_fm, enc_H, enc_W), dtype=np.float32)
    chan_avg  = np.zeros(C_fm, dtype=np.float32)   # mean avg activation per channel
    for enc in all_encodeds:
        arr = (enc[0] if enc.ndim == 4 else enc).astype(np.float32)
        vmin, vmax = arr.min(), arr.max()
        if vmax > vmin:
            arr = (arr - vmin) / (vmax - vmin)
        if arr.ndim == 3:
            for c in range(C_fm):
                chan_maps[c] += arr[:, :, c]
                chan_avg[c]  += arr[:, :, c].mean()
    chan_maps /= R_fm
    chan_avg  /= R_fm

    # Upscale each 7×7 map to image_side×image_side using bilinear interpolation.
    scale = image_side / enc_H
    fm_images = np.array([
        np.array(Image.fromarray((m * 255).astype(np.uint8)).resize(
            (image_side, image_side), Image.BILINEAR), dtype=np.float32) / 255.0
        for m in chan_maps
    ])

    # Grid layout: try to be roughly square.
    n_cols = int(np.ceil(np.sqrt(C_fm)))
    n_rows = int(np.ceil(C_fm / n_cols))
    fig, axes = plt.subplots(n_rows, n_cols,
                             figsize=(n_cols * 1.8, n_rows * 2.0))
    fig.suptitle(
        "Feature detector maps — {}  layer {}  ({} runs)".format(
            model_name, encoder_layer, R_fm),
        fontsize=9)
    for c in range(n_rows * n_cols):
        ax = axes.flat[c]
        if c < C_fm:
            ax.imshow(fm_images[c], cmap="hot", vmin=0, vmax=1)
            ax.set_title("ch {}  avg={:.2f}".format(c, chan_avg[c]), fontsize=7)
        ax.axis("off")
    plt.tight_layout()
    fm_path = os.path.join(args.output_dir, "feature_maps.png")
    fig.savefig(fm_path, dpi=150, bbox_inches="tight")
    print("Feature maps saved to {}".format(fm_path))

# ── Activation maximisation maps ───────────────────────────────────────────────

if args.activation_maps:
    print("\nComputing activation maximisation maps ({} steps, lr={}) ...".format(
        args.gradient_steps, args.gradient_lr))
    try:
        import tensorflow as tf
    except ImportError:
        print("TensorFlow not available — skipping --activation-maps.")
    else:
        C_am = encoder_shape[-1]
        n_steps_grad = args.gradient_steps
        lr_grad      = args.gradient_lr

        act_imgs = []
        for c in tqdm(range(C_am), desc="channels"):
            x = tf.Variable(np.random.random(input_shape).astype(np.float32))
            for _ in range(n_steps_grad):
                with tf.GradientTape() as tape:
                    enc, _ = model(x, training=False)
                    if len(enc.shape) == 4:
                        loss = tf.reduce_mean(enc[0, :, :, c])
                    else:
                        loss = enc[0, c]
                grads = tape.gradient(loss, x)
                x.assign_add(grads * lr_grad)
                x.assign(tf.clip_by_value(x, 0.0, 1.0))

            result = x.numpy()
            img = (result[0, :, :, 0] if result.ndim == 4
                   else result[0].reshape(image_side, image_side))
            act_imgs.append(img)

        n_cols = int(np.ceil(np.sqrt(C_am)))
        n_rows = int(np.ceil(C_am / n_cols))
        fig, axes = plt.subplots(n_rows, n_cols,
                                 figsize=(n_cols * 1.8, n_rows * 2.0))
        fig.suptitle(
            "Activation maximisation — {}  layer {}  ({} steps, lr={})".format(
                model_name, encoder_layer, n_steps_grad, lr_grad),
            fontsize=9)
        for c in range(n_rows * n_cols):
            ax = axes.flat[c]
            if c < C_am:
                ax.imshow(act_imgs[c], cmap="gray", vmin=0, vmax=1)
                ax.set_title("ch {}".format(c), fontsize=7)
            ax.axis("off")
        plt.tight_layout()
        am_path = os.path.join(args.output_dir, "activation_maps.png")
        fig.savefig(am_path, dpi=150, bbox_inches="tight")
        print("Activation maximisation maps saved to {}".format(am_path))

vec_idx = {"min": 0, "max": 1, "avg": 2}[args.vector]
# all_vecs: (R, T, C)
all_vecs = np.array([[sig[vec_idx] for sig in run] for run in all_runs])
R, T, C = all_vecs.shape
print("Collected tensor: {} runs × {} steps × {} channels".format(R, T, C))

final_vecs = all_vecs[:, -1, :]   # (R, C) — state after all feedback steps
first_vecs = all_vecs[:,  0, :]   # (R, C) — state after 1 step

# ── Text report ────────────────────────────────────────────────────────────────

lines = []
SEP = "=" * 62

def h(title):
    lines.append("\n--- {} ---".format(title))

lines.append(SEP)
lines.append("ENCODER ACTIVATION ANALYSIS")
lines.append("Model        : {}".format(model_name))
lines.append("Encoder layer: {}  shape: {}".format(encoder_layer, encoder_shape))
lines.append("Vector       : {}  |  {} runs × {} steps × {} channels".format(
    args.vector, R, T, C))
lines.append(SEP)

# 1. Global amplitude
flat_all = all_vecs.reshape(-1)
h("AMPLITUDE (all values, all runs, all steps)")
lines.append("  mean : {:.4f}".format(flat_all.mean()))
lines.append("  std  : {:.4f}".format(flat_all.std()))
lines.append("  min  : {:.4f}".format(flat_all.min()))
lines.append("  max  : {:.4f}".format(flat_all.max()))
lines.append("  p25  : {:.4f}".format(np.percentile(flat_all, 25)))
lines.append("  p75  : {:.4f}".format(np.percentile(flat_all, 75)))

# 2. Per-channel amplitude
ch_vals = all_vecs.reshape(-1, C)   # (R*T, C)
ch_mean = ch_vals.mean(axis=0)
ch_std  = ch_vals.std(axis=0)
ch_min  = ch_vals.min(axis=0)
ch_max  = ch_vals.max(axis=0)
ch_range = ch_max - ch_min
h("PER-CHANNEL AMPLITUDE (across all runs & steps)")
lines.append("  {:>4}  {:>7}  {:>7}  {:>7}  {:>7}".format(
    "ch", "mean", "std", "min", "max"))
for c in range(C):
    lines.append("  {:>4d}  {:>7.4f}  {:>7.4f}  {:>7.4f}  {:>7.4f}".format(
        c, ch_mean[c], ch_std[c], ch_min[c], ch_max[c]))

# 3. Sparsity
THRESH = args.sparsity_threshold
sparsity_global = (all_vecs < THRESH).mean()
sparsity_per_ch = (ch_vals < THRESH).mean(axis=0)
dead = [c for c in range(C) if (ch_vals[:, c] < THRESH).all()]
low_range = [c for c in range(C) if ch_range[c] < 0.1]
h("SPARSITY  (threshold = {})".format(THRESH))
lines.append("  Fraction of values < threshold : {:.3f}".format(sparsity_global))
lines.append("  Dead channels (always < thresh): {} / {}  {}".format(
    len(dead), C, dead if dead else "none"))
lines.append("  Low-range channels (range<0.1) : {} / {}  {}".format(
    len(low_range), C, low_range if low_range else "none"))
lines.append("  Per-channel sparsity fraction  : {}".format(
    "  ".join("{:.2f}".format(v) for v in sparsity_per_ch)))

# 4. Inter-run diversity (at final step)
inter_std = final_vecs.std(axis=0)   # (C,)
pairwise  = pdist(final_vecs, metric="euclidean")
h("INTER-RUN DIVERSITY  (std of final-step vector across {} runs)".format(R))
lines.append("  Mean inter-run std : {:.4f}".format(inter_std.mean()))
lines.append("  Max  inter-run std : {:.4f}  (ch {})".format(
    inter_std.max(), inter_std.argmax()))
lines.append("  Min  inter-run std : {:.4f}  (ch {})".format(
    inter_std.min(), inter_std.argmin()))
lines.append("  Pairwise Euclidean dist → mean={:.4f}  std={:.4f}  max={:.4f}".format(
    pairwise.mean(), pairwise.std(), pairwise.max()))

# 5. Intra-run evolution
deltas      = np.diff(all_vecs, axis=1)          # (R, T-1, C)
delta_norms = np.linalg.norm(deltas, axis=2)     # (R, T-1)
h("INTRA-RUN EVOLUTION  (step-to-step ||Δvec|| over {} steps)".format(T))
lines.append("  Mean step delta norm : {:.4f}".format(delta_norms.mean()))
lines.append("  Std  step delta norm : {:.4f}".format(delta_norms.std()))
if T > 1:
    lines.append("  Per-step mean        : {}".format(
        "  ".join("{:.4f}".format(v) for v in delta_norms.mean(axis=0))))

# Convergence: does the vector settle across steps?
if T > 2:
    early = delta_norms[:, :T//2].mean()
    late  = delta_norms[:, T//2:].mean()
    lines.append("  Early half mean delta: {:.4f}  |  Late half: {:.4f}  ({})".format(
        early, late, "converging" if late < early else "diverging"))

# 6. Channel correlation
corr_matrix = np.corrcoef(final_vecs.T)          # (C, C)
upper = corr_matrix[np.triu_indices(C, k=1)]
h("CHANNEL CORRELATION  (final-step vectors, across runs)")
lines.append("  Mean |corr|         : {:.4f}".format(np.abs(upper).mean()))
lines.append("  Fraction |corr|>0.8 : {:.3f}".format((np.abs(upper) > 0.8).mean()))
lines.append("  Fraction |corr|>0.5 : {:.3f}".format((np.abs(upper) > 0.5).mean()))

# 7. PCA dimensionality
pca = PCA()
pca.fit(final_vecs)
cumvar = np.cumsum(pca.explained_variance_ratio_)
n90 = int(np.searchsorted(cumvar, 0.90)) + 1
n99 = int(np.searchsorted(cumvar, 0.99)) + 1
h("PCA DIMENSIONALITY  (effective degrees of freedom)")
lines.append("  Components for 90% variance: {}  / {}".format(n90, C))
lines.append("  Components for 99% variance: {}  / {}".format(n99, C))
lines.append("  Explained variance per PC  : {}".format(
    "  ".join("{:.3f}".format(v) for v in pca.explained_variance_ratio_)))

# 8. Interpretation summary
h("INTERPRETATION SUMMARY")
issues = []
positives = []

if sparsity_global > 0.5:
    issues.append("High global sparsity ({:.0%}) — many channels near-zero; limited sound variety.".format(
        sparsity_global))
else:
    positives.append("Sparsity is moderate ({:.0%}); channels carry signal.".format(sparsity_global))

if dead:
    issues.append("{} dead channels contribute nothing to the sonoscope.".format(len(dead)))
if low_range:
    issues.append("{} channels have very low range (<0.1); sound effect will be weak.".format(
        len(low_range)))

if inter_std.mean() < 0.05:
    issues.append("Low inter-run diversity (mean std {:.4f}) — different generations sound similar.".format(
        inter_std.mean()))
elif inter_std.mean() > 0.15:
    positives.append("Good inter-run diversity (mean std {:.4f}) — generations should sound distinct.".format(
        inter_std.mean()))

if (np.abs(upper) > 0.8).mean() > 0.3:
    issues.append("Many highly-correlated channel pairs (>{:.0%}) — redundant sound dimensions.".format(
        (np.abs(upper) > 0.8).mean()))
else:
    positives.append("Channel correlations are low; channels carry relatively independent information.")

if n90 < C // 2:
    issues.append("Only {} PCs needed for 90% variance — the vector lives in a low-dim subspace.".format(n90))
else:
    positives.append("{} PCs needed for 90% variance — good use of the full {} dimensions.".format(n90, C))

for p in positives:
    lines.append("  [+] " + p)
for i in issues:
    lines.append("  [!] " + i)

lines.append("\n" + SEP)
report_text = "\n".join(lines)
print("\n" + report_text)

report_path = os.path.join(args.output_dir, "report.txt")
with open(report_path, "w") as f:
    f.write(report_text + "\n")
print("Report saved to {}".format(report_path))

# ── Plots ──────────────────────────────────────────────────────────────────────

fig = plt.figure(figsize=(18, 14))
fig.suptitle(
    "Encoder Analysis — {}  |  layer {}  |  vector: {}  |  {} runs × {} steps".format(
        model_name, encoder_layer, args.vector, R, T),
    fontsize=11)
gs = gridspec.GridSpec(3, 3, figure=fig, hspace=0.50, wspace=0.38)

# 1. Per-channel mean ± std
ax = fig.add_subplot(gs[0, 0])
x = np.arange(C)
ax.bar(x, ch_mean, yerr=ch_std, capsize=3, color="steelblue", alpha=0.8)
ax.set_title("Per-channel mean ± std")
ax.set_xlabel("Channel")
ax.set_ylabel(args.vector)
ax.set_ylim(0, 1)
ax.axhline(THRESH, color="red", linestyle="--", linewidth=0.8, label="sparsity thresh")
ax.legend(fontsize=7)

# 2. Inter-run diversity per channel
ax = fig.add_subplot(gs[0, 1])
ax.bar(x, inter_std, color="darkorange", alpha=0.8)
ax.set_title("Inter-run diversity (std per channel)")
ax.set_xlabel("Channel")
ax.set_ylabel("Std across {} runs".format(R))

# 3. Value distribution
ax = fig.add_subplot(gs[0, 2])
ax.hist(flat_all, bins=60, color="mediumseagreen", alpha=0.85, edgecolor="none")
ax.axvline(THRESH, color="red", linestyle="--", linewidth=0.9, label="sparsity thresh")
ax.set_title("Global value distribution")
ax.set_xlabel("Value")
ax.set_ylabel("Count")
ax.legend(fontsize=7)

# 4. Intra-run evolution (mean ± std of delta norm over steps)
ax = fig.add_subplot(gs[1, 0])
if T > 1:
    mean_d = delta_norms.mean(axis=0)
    std_d  = delta_norms.std(axis=0)
    steps  = np.arange(1, T)
    ax.plot(steps, mean_d, color="steelblue")
    ax.fill_between(steps, mean_d - std_d, mean_d + std_d, alpha=0.25, color="steelblue")
ax.set_title("Step-to-step delta norm (intra-run)")
ax.set_xlabel("Step")
ax.set_ylabel("||Δvec||")

# 5. Channel correlation matrix
ax = fig.add_subplot(gs[1, 1])
im = ax.imshow(corr_matrix, vmin=-1, vmax=1, cmap="RdBu_r", aspect="auto")
plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
ax.set_title("Channel correlation (final step)")
ax.set_xlabel("Channel")
ax.set_ylabel("Channel")

# 6. PCA explained variance
ax = fig.add_subplot(gs[1, 2])
pc_idx = np.arange(1, len(pca.explained_variance_ratio_) + 1)
ax.bar(pc_idx, pca.explained_variance_ratio_ * 100, color="mediumpurple", alpha=0.8)
ax.plot(pc_idx, cumvar * 100, "k--", marker="o", markersize=3)
ax.axhline(90, color="red",    linestyle=":", linewidth=0.9, label="90%")
ax.axhline(99, color="orange", linestyle=":", linewidth=0.9, label="99%")
ax.set_title("PCA explained variance")
ax.set_xlabel("Component")
ax.set_ylabel("Variance (%)")
ax.legend(fontsize=7)

# 7. PCA scatter: PC1 vs PC2 (final step, colored by run index)
ax = fig.add_subplot(gs[2, 0])
proj = pca.transform(final_vecs)
sc = ax.scatter(proj[:, 0], proj[:, 1], c=np.arange(R), cmap="plasma", alpha=0.7, s=18)
plt.colorbar(sc, ax=ax, fraction=0.046, pad=0.04, label="run index")
ax.set_title("PCA: PC1 vs PC2 (final step)")
ax.set_xlabel("PC1")
ax.set_ylabel("PC2")

# 8. Vector heatmap over steps for a sample run
ax = fig.add_subplot(gs[2, 1])
traj = all_vecs[0]   # (T, C) — run 0
im = ax.imshow(traj.T, aspect="auto", origin="lower", vmin=0, vmax=1, cmap="viridis")
plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
ax.set_title("Run 0: vector evolution over steps")
ax.set_xlabel("Step")
ax.set_ylabel("Channel")

# 9. Pairwise Euclidean distance distribution
ax = fig.add_subplot(gs[2, 2])
ax.hist(pairwise, bins=40, color="tomato", alpha=0.85, edgecolor="none")
ax.axvline(pairwise.mean(), color="black", linestyle="--", linewidth=0.9,
           label="mean {:.3f}".format(pairwise.mean()))
ax.set_title("Pairwise distance (final step)")
ax.set_xlabel("Euclidean distance")
ax.set_ylabel("Count")
ax.legend(fontsize=7)

plot_path = os.path.join(args.output_dir, "encoder_analysis.png")
fig.savefig(plot_path, dpi=150, bbox_inches="tight")
print("Plot saved to {}".format(plot_path))

# Save raw vectors for further analysis
np_path = os.path.join(args.output_dir, "all_vecs.npy")
np.save(np_path, all_vecs)
print("Raw vectors saved to {}".format(np_path))

# Save as plain text for Pd: one vector per line, space-separated floats.
# Pd's [text] object can read this directly with a "read filename" message
# and retrieve row N as a list with a "get N" message.
txt_path = os.path.join(args.output_dir, "all_vecs.txt")
np.savetxt(txt_path, all_vecs.reshape(-1, C), fmt="%.6f", newline=";\n")
print("Text vectors saved to {}  ({} rows × {} cols)  — for Pd [text]".format(
    txt_path, R * T, C))
