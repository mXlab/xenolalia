"""xeno_vec_player.py — interactively send pre-generated encoder vectors via OSC.

Loads a vector dataset (.npy, .csv, or .json), then lets you drive playback
from the interactive terminal OR via OSC control messages from a Pd patch /
Open Stage Control.

Simulates the activation messages that XenoProjection sends during a live run,
so you can test the Pd sonoscope patch without running the full system.

Usage:
    python xeno_vec_player.py analysis/all_vecs.npy
    python xeno_vec_player.py analysis/all_vecs.npy -tp 7002 -rp 7010

Terminal controls:
    Enter / b   → bang: send current vector
    <number>    → select vector at that index
    n           → advance to next vector
    q           → quit

OSC control (default receive port 7010):
    /bang          → send current vector
    /select <int>  → select vector at index
    /next          → advance to next vector
"""

import argparse
import json
import os
import sys
import threading

import numpy as np
from pythonosc import dispatcher as osc_dispatcher
from pythonosc import osc_server
from pythonosc import udp_client

# ── CLI ────────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(
    formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    description=__doc__,
)
parser.add_argument("file", type=str,
                    help="Vector file: .npy (N×C or R×T×C), .csv (N×C), or .json")
parser.add_argument("-ip", "--target-ip",   type=str, default="127.0.0.1",
                    help="IP of the Pd sonoscope target")
parser.add_argument("-tp", "--target-port", type=int, default=7002,
                    help="OSC port of the Pd sonoscope")
parser.add_argument("-rp", "--receive-port", type=int, default=7010,
                    help="Port to listen on for OSC control messages")
parser.add_argument("--address", type=str,
                    default="/xeno/sonoscope/activations/start",
                    help="OSC address for activation messages")
args = parser.parse_args()

# ── Load vectors ───────────────────────────────────────────────────────────────

def load_vectors(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".npy":
        arr = np.load(path)
        if arr.ndim == 3:
            R, T, C = arr.shape
            arr = arr.reshape(R * T, C)
            print("Loaded .npy  {} runs × {} steps × {} ch  →  {} vectors".format(R, T, C, R * T))
        elif arr.ndim == 2:
            print("Loaded .npy  {} vectors × {} channels".format(*arr.shape))
        else:
            raise ValueError("Expected 2D or 3D npy array, got shape {}".format(arr.shape))
    elif ext == ".csv":
        arr = np.loadtxt(path, delimiter=",")
        if arr.ndim == 1:
            arr = arr[np.newaxis, :]
        print("Loaded .csv  {} vectors × {} channels".format(*arr.shape))
    elif ext == ".json":
        with open(path) as f:
            data = json.load(f)
        # Support: list of lists, or list of code-signature dicts (with avg/max/min keys)
        if isinstance(data, list) and len(data) and isinstance(data[0], dict):
            key = next((k for k in ("avg", "max", "min") if k in data[0]), None)
            if key is None:
                raise ValueError("JSON dicts have no 'avg', 'max', or 'min' key")
            arr = np.array([d[key] for d in data], dtype=np.float32)
        else:
            arr = np.array(data, dtype=np.float32)
            if arr.ndim == 1:
                arr = arr[np.newaxis, :]
        print("Loaded .json  {} vectors × {} channels".format(*arr.shape))
    else:
        raise ValueError("Unsupported file format: {}".format(ext))
    return arr.astype(np.float32)

vectors = load_vectors(args.file)
N, C = vectors.shape
_idx = [0]   # mutable for closures

# ── OSC client ─────────────────────────────────────────────────────────────────

client = udp_client.SimpleUDPClient(args.target_ip, args.target_port)

# ── Actions ────────────────────────────────────────────────────────────────────

def send_current():
    vec = vectors[_idx[0]]
    payload = [float(v) for v in vec]
    client.send_message(args.address, payload)
    print("→ vec[{:4d}]  {}".format(
        _idx[0],
        " ".join("{:.3f}".format(v) for v in payload)))

def select(idx):
    _idx[0] = int(idx) % N
    print("  index → {}".format(_idx[0]))

def advance():
    _idx[0] = (_idx[0] + 1) % N
    print("  index → {}".format(_idx[0]))

# ── OSC server (control input) ─────────────────────────────────────────────────

disp = osc_dispatcher.Dispatcher()
disp.map("/bang",   lambda addr:       send_current())
disp.map("/select", lambda addr, idx:  select(idx))
disp.map("/index",  lambda addr, idx:  select(idx))   # alias
disp.map("/next",   lambda addr:       advance())

osc_recv = osc_server.ThreadingOSCUDPServer(("0.0.0.0", args.receive_port), disp)
threading.Thread(target=osc_recv.serve_forever, daemon=True).start()

# ── Interactive CLI ────────────────────────────────────────────────────────────

print()
print("  Vectors : {} × {} channels".format(N, C))
print("  Send to : {}:{}  {}".format(args.target_ip, args.target_port, args.address))
print("  OSC in  : 0.0.0.0:{}  (/bang  /select <n>  /next)".format(args.receive_port))
print()
print("  Enter / b  →  send current vector")
print("  <number>   →  select vector index")
print("  n          →  next vector")
print("  q          →  quit")
print()

while True:
    try:
        line = input("vec[{}]> ".format(_idx[0])).strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        break
    if line in ("", "b"):
        send_current()
    elif line == "n":
        advance()
    elif line == "q":
        break
    else:
        try:
            select(int(line))
        except ValueError:
            print("  ? Enter a number, 'b' to send, 'n' for next, 'q' to quit.")

osc_recv.server_close()
