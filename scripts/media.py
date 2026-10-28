#!/usr/bin/env python3
"""Minimal stdlib helpers for safe FFmpeg format conversion and JSON clip batches."""
import argparse
import json
import re
import subprocess
from pathlib import Path

TIME = re.compile(r"^(?:\d+:)?[0-5]?\d:[0-5]\d(?:\.\d+)?$")
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,100}$")


def run(args, output, overwrite):
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not overwrite:
        raise SystemExit(f"Refusing to replace {output}; set OVERWRITE=1")
    subprocess.run(args, check=True)


def validate_clips(data):
    if not isinstance(data, list) or not data:
        raise ValueError("Manifest must be a nonempty JSON array")
    if len(data) > 100:
        raise ValueError("Maximum 100 clips per manifest")
    names = set()
    for clip in data:
        if not isinstance(clip, dict) or set(clip) != {"name", "start", "duration"}:
            raise ValueError("Every clip needs exactly name, start, duration")
        name, start, duration = (clip[k] for k in ("name", "start", "duration"))
        if not isinstance(name, str) or not NAME.fullmatch(name) or name in {".", ".."}:
            raise ValueError(f"Invalid clip name: {name!r}")
        if name in names:
            raise ValueError(f"Duplicate clip name: {name}")
        names.add(name)
        if not all(isinstance(t, str) and TIME.fullmatch(t) for t in (start, duration)):
            raise ValueError(f"Invalid time in {name}")
        if float(duration.split(":")[-1]) == 0 and all(int(x) == 0 for x in duration.split(":")[:-1]):
            raise ValueError(f"Zero duration in {name}")
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    sp = ap.add_subparsers(dest="command", required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--ffmpeg", required=True)
    common.add_argument("--input", required=True)
    common.add_argument("--overwrite", choices=("0", "1"), default="0")
    convert = sp.add_parser("convert", parents=[common])
    convert.add_argument("--format", choices=("mp4", "mkv", "mov", "webm"), required=True)
    convert.add_argument("--output", required=True)
    clips = sp.add_parser("clips", parents=[common])
    clips.add_argument("--manifest", required=True)
    clips.add_argument("--outdir", required=True)
    a = ap.parse_args()
    if a.command == "convert":
        if a.format == "webm":
            codecs = ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"]
        else:
            codecs = ["-c:v", "libx264", "-crf", "23", "-c:a", "aac"]
        run([a.ffmpeg, "-hide_banner", "-y" if a.overwrite == "1" else "-n", "-i", a.input,
             "-map", "0:v:0", "-map", "0:a?", *codecs, a.output], a.output, a.overwrite == "1")
    else:
        data = validate_clips(json.loads(Path(a.manifest).read_text(encoding="utf-8")))
        dest = Path(a.outdir)
        for clip in data:
            output = dest / (clip["name"] + ".mp4")
            run([a.ffmpeg, "-hide_banner", "-y" if a.overwrite == "1" else "-n",
                 "-ss", clip["start"], "-i", a.input, "-t", clip["duration"],
                 "-map", "0:v:0", "-map", "0:a?", "-c:v", "libx264", "-preset", "veryfast",
                 "-crf", "20", "-c:a", "aac", str(output)], output, a.overwrite == "1")


if __name__ == "__main__":
    main()
