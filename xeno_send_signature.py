#!/usr/bin/env python3
"""Send encoder code signature vectors to the sonoscope via OSC, for testing."""

import argparse
import glob
import json
import os
import time

from pythonosc import udp_client

OSC_ADDRESS = "/xeno/sonoscope/activations"


def find_signature_files(path):
    """Return sorted list of _code_signature.json files under path."""
    if os.path.isfile(path):
        return [path]
    files = sorted(glob.glob(os.path.join(path, "**/*_code_signature.json"), recursive=True))
    return files


def load_signature(filepath):
    with open(filepath) as f:
        return json.load(f)


def send(client, data, vector, duration):
    values = data[vector]
    info = "model={} shape={} n={}".format(
        data.get("model", "?"),
        data.get("encoder_shape", "?"),
        len(values),
    )
    print("  /start  vector={}  {}".format(vector, info))
    client.send_message(OSC_ADDRESS + "/start", values)
    if duration > 0:
        time.sleep(duration)
        client.send_message(OSC_ADDRESS + "/end", 0)
        print("  /end")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Send encoder code signature to sonoscope via OSC.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "path",
        help="Path to a _code_signature.json file or a directory to scan recursively.",
    )
    parser.add_argument(
        "--vector", choices=["min", "max", "avg"], default="avg",
        help="Which feature vector to send.",
    )
    parser.add_argument(
        "--ip", default="127.0.0.1",
        help="Sonoscope IP address.",
    )
    parser.add_argument(
        "--port", type=int, default=7002,
        help="Sonoscope OSC port.",
    )
    parser.add_argument(
        "--duration", type=float, default=5.0,
        help="Seconds to hold before sending /end (0 = skip /end).",
    )
    parser.add_argument(
        "--loop", action="store_true",
        help="Loop through all signatures found, in chronological order.",
    )
    parser.add_argument(
        "--interval", type=float, default=8.0,
        help="Seconds between sends when --loop is active.",
    )
    args = parser.parse_args()

    client = udp_client.SimpleUDPClient(args.ip, args.port)
    files = find_signature_files(args.path)

    if not files:
        print("No _code_signature.json files found at: {}".format(args.path))
        exit(1)

    if args.loop:
        print("Looping over {} file(s) — Ctrl-C to stop".format(len(files)))
        while True:
            for filepath in files:
                print(os.path.basename(os.path.dirname(filepath)))
                data = load_signature(filepath)
                send(client, data, args.vector, args.duration)
                gap = args.interval - args.duration
                if gap > 0:
                    time.sleep(gap)
    else:
        filepath = files[-1]
        print(os.path.basename(filepath))
        data = load_signature(filepath)
        send(client, data, args.vector, args.duration)
