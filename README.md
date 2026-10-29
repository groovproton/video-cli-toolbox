# Video CLI Toolbox

A pragmatic, cross-platform **Makefile command collection for FFmpeg, local Whisper, and optional yt-dlp**. Inspect, compress, convert, trim, extract audio, export frames, make GIFs, and transcribe videos into timestamped SRT subtitles. No Docker, no Node.js, and no cloud account required.

Useful for tutorials, recordings, and other videos: transcribe an entire lesson, identify interesting timestamps, then extract just the clips worth reviewing.

## Requirements

- `make`, `ffmpeg`, `ffprobe`, and Python 3 with `venv`.
- FFmpeg must have the required encoders (`libx264`, `libmp3lame`, `libvpx-vp9` for WebM).
- For speech-to-text only: Python environment and enough disk space for PyTorch plus a Whisper model. Whisper downloads model weights on first use. Apple Silicon support/performance depends on the installed PyTorch backend.

### Install FFmpeg

**macOS (Homebrew)**

```sh
brew install ffmpeg
```

If you already have FFmpeg, check `ffmpeg -version`; there's no need to upgrade for this project.

**Ubuntu / Debian**

```sh
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv make
```

**Windows**

Use WSL2 (Ubuntu) and follow the Linux instructions. Native Windows Make environments may vary; WSL is the documented supported route.

Verify:

```sh
make doctor
```

### Install Whisper (optional)

```sh
make install-whisper
```

This creates `.venv/`, installs the open-source `openai-whisper` Python package, and keeps it separate from your system Python. On first transcription, model weights are downloaded. Transcription subsequently runs locally.

### Install yt-dlp (optional)

**macOS (Homebrew)**

```sh
brew install yt-dlp
```

**Linux / Windows WSL** (isolated Python installation):

```sh
python3 -m venv .venv-ytdlp
.venv-ytdlp/bin/python -m pip install -U yt-dlp
make yt-doctor YTDLP=.venv-ytdlp/bin/yt-dlp
```

Or install from the official [yt-dlp installation guide](https://github.com/yt-dlp/yt-dlp/wiki/Installation). FFmpeg is used for merging separate streams, audio extraction and SRT conversion. Check versions with `make yt-doctor`. yt-dlp may need updating when sites change.

## Quick start

```sh
make help
make info INPUT='lesson.mp4'
make subtitles INPUT='lesson.mp4' LANG=English MODEL=small
make trim INPUT='lesson.mp4' START=00:05:20 DURATION=00:01:25
make compress INPUT='lesson.mp4' CRF=28
```

Generated files go into `output/` unless you set `OUTDIR=...`; use `OUTPUT=...` to choose a file path for single-file targets. Existing output files, including generated SRT files, are protected by default; pass `OVERWRITE=1` to replace them.

> **Tip:** use shell quotes for paths containing spaces. `INPUT` is required for media commands; it defaults to `input.mp4` as a convenience.

## All commands

| Target | Purpose | Example / options |
| --- | --- | --- |
| `help` | Discover targets | `make help` |
| `doctor` | Check FFmpeg, ffprobe, Python, Whisper | `make doctor` |
| `install-whisper` | Install local Whisper in `.venv` | `make install-whisper` |
| `info` | Stream, codec, duration, bitrate metadata | `make info INPUT=movie.mov` |
| `compress` | H.264/AAC MP4; smaller with higher `CRF` | `make compress INPUT=movie.mov CRF=27 PRESET=medium` |
| `convert` | Re-encode to MP4, MKV, MOV or WebM | `make convert INPUT=movie.mp4 FORMAT=webm` |
| `trim` | Accurate, re-encoded video section | `make trim INPUT=movie.mp4 START=00:03:00 DURATION=00:00:20` |
| `audio` | Copy first audio track without loss | `make audio INPUT=movie.mp4` → `.mka` |
| `mp3` | Encode audio to MP3 | `make mp3 INPUT=movie.mp4 AUDIO_BITRATE=192k` |
| `wav` | Make 16-kHz mono WAV | `make wav INPUT=movie.mp4` |
| `frames` | Export numbered JPG frames | `make frames INPUT=movie.mp4 FPS=1` |
| `thumbnail` | Capture a JPG at a specific time | `make thumbnail INPUT=movie.mp4 START=00:03:12` |
| `gif` | Make a short optimized-palette GIF | `make gif INPUT=movie.mp4 START=00:01:00 DURATION=00:00:05 FPS=10 WIDTH=640` |
| `subtitles` | Run Whisper and produce `.srt` | `make subtitles INPUT=movie.mp4 MODEL=small LANG=Russian` |
| `extract-subs` | Convert first existing embedded subtitle stream to SRT | `make extract-subs INPUT=movie.mkv` |
| `clips` | Extract batch clips from JSON | `make clips INPUT=movie.mp4 CLIPS=examples/clips.json` |
| `test` | Run Python stdlib tests | `make test` |
| `clean` | Remove `OUTDIR` output | `make clean` |

## Download media with yt-dlp (optional)

These commands work on supported sites, subject to site changes, permissions and availability. **They do not circumvent DRM.** Download only content you are authorized to obtain, and respect the source website's terms and copyright.

All yt-dlp downloads go directly into the **current working directory**, not into `output/`. You can override the destination with `YT_OUTDIR=/some/path` when invoking Make directly. Single-video targets use `--no-playlist` deliberately. Filenames contain the media ID to reduce collisions; existing files are protected.

| Target | Purpose | Example |
| --- | --- | --- |
| `yt-doctor` | Check yt-dlp version | `make yt-doctor` |
| `yt-info` | Print source information | `make yt-info URL='https://example.com/watch?v=123'` |
| `yt-formats` | List available video/audio streams | `make yt-formats URL='https://example.com/watch?v=123'` |
| `yt-subs-list` | List available subtitle languages | `make yt-subs-list URL='https://example.com/watch?v=123'` |
| `yt-video` | Download one video and audio | `make yt-video URL='https://example.com/watch?v=123'` |
| `yt-audio` | Download audio and convert, default MP3 | `make yt-audio URL='https://example.com/watch?v=123'` |
| `yt-subs` | Download manual subtitles as SRT | `make yt-subs URL='https://example.com/watch?v=123' YT_LANG=en` |
| `yt-auto-subs` | Download generated subtitles as SRT | `make yt-auto-subs URL='https://example.com/watch?v=123' YT_LANG=ru` |
| `yt-section` | Download part of a video | `make yt-section URL='https://example.com/watch?v=123' YT_SECTION_START=00:01:00 YT_SECTION_END=00:02:00` |
| `yt-playlist` | Explicitly download a playlist | `make yt-playlist URL='https://example.com/playlist?list=123'` |

**Defaults:** `YT_BROWSER=vivaldi`, `YT_CONTAINER=mp4`, `YT_FORMAT='bv[ext=mp4]+ba[ext=m4a]/bv+ba/b'`, `YT_AUDIO_FORMAT=mp3`, `YT_LANG=en`. Override with command-line variables (for example `YT_BROWSER=` disables reading browser cookies). `YTDLP` chooses the binary; `YT_FORMAT` selects video/audio streams (default `bv*+ba/b`); `YT_LANG` specifies subtitle language tags such as `en`, `ru`, or `en.*`; `YT_AUDIO_FORMAT` defaults to `mp3`.

`yt-subs` and `yt-auto-subs` retrieve subtitles already available from the source; unlike Whisper, they do **not** recognize speech themselves. If subtitles aren't available, download the video then use `make subtitles INPUT='path/to/video.mp4'`.

The MP4 preference is not a guarantee if the source lacks compatible streams; inspect `yt-formats` when needed. Cookies are sensitive: never commit browser profiles or exported cookies. The `yt-section` start/end are **absolute timestamps**, not start/duration, and section boundaries may depend on keyframes. The playlist command uses a download archive to avoid duplicate downloads. Large playlists can consume substantial disk space. URLs containing `&` or `?` must be quoted in your shell.

## Simple command-line wrappers

Four executable POSIX shell scripts in `bin/` accept **one positional URL** and
call the Makefile from any working directory. Downloads are saved into the directory from which you invoked the wrapper, even though the wrapper calls `make -C`. All standard yt-dlp defaults
(Vivaldi cookies, MP4 preference, MP3 and English subtitles) are inherited.

```sh
./bin/yt-video 'https://www.youtube.com/watch?v=VIDEO_ID'
./bin/yt-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
./bin/yt-subs-en 'https://www.youtube.com/watch?v=VIDEO_ID'
./bin/yt-subs-ru 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Use `./bin/yt-video` while in the project root, or add the absolute
`bin/` directory to your shell `PATH` for global commands.
Each script requires exactly one HTTP(S) URL; otherwise it prints usage and
exits with a nonzero status. Quote URLs containing `&` and `?`.
For options beyond these defaults, use the existing `make yt-*` targets. Playlist downloads also keep their download archive as a hidden `.yt-dlp-archive.txt` in the destination directory.

## Recommended tutorial workflow

1. Transcribe the original lesson, retaining timestamps:

   ```sh
   make subtitles INPUT='lecture 07.mp4' MODEL=small LANG=English
   ```

2. Give `output/lecture 07.srt` to your AI assistant; ask it to identify the assignment and any portions that must be visually inspected.
3. Store needed segments in a JSON manifest:

   ```json
   [
     {"name": "chapter-one", "start": "00:05:20", "duration": "00:01:25"},
     {"name": "summary", "start": "00:36:15", "duration": "00:01:45"}
   ]
   ```

4. Cut all requested video clips:

   ```sh
   make clips INPUT='lecture 07.mp4' CLIPS=examples/clips.json
   ```

5. Share `output/clips/*.mp4` or screenshots for focused review. Video support and limits depend on the AI service used.

## Important options and behavior

- `CRF=25`: H.264 quality/size tradeoff; ~18 visually higher quality, ~28 smaller size. Not a target file size. Compression can sometimes increase file size.
- `PRESET=medium`: encoder speed vs compression efficiency. Faster presets produce larger files at similar quality.
- `START` and `DURATION`: clip start and **length**, not end time. `trim` and `clips` re-encode for accurate cuts rather than requiring keyframe boundaries.
- `LANG=auto`: Whisper detects spoken language. `LANG=English` or `Russian` selects it explicitly. Preserve original spoken language by using `TASK=transcribe` (default); `TASK=translate` produces English translations supported by Whisper.
- `MODEL=small`: first choice for local transcription. `medium` or `large` can improve recognition but use more RAM and CPU/GPU resources.
- `FORMAT=webm`: uses VP9 video and Opus audio; other conversion formats use H.264 video and AAC audio. Some source/target/container combinations are not compatible.
- `extract-subs` only works when a subtitle stream exists and is compatible with SRT. It does not recognize speech. Use `subtitles` for videos with no subtitle track.
- `frames` creates `output/frames/frame_000001.jpg` etc.; reduce `FPS` for long recordings to avoid thousands of images.
- `audio` preserves the existing first audio track in Matroska Audio (`.mka`) without re-encoding; use `mp3` for broadly playable output.
- Metadata, attachments, chapter marks and extra streams are not preserved by the simple conversion commands. This collection primarily handles the first video and optionally audio streams.
- `OUTPUT` applies to single-output commands, not `frames`, `subtitles` or `clips`. Parent directories of `OUTPUT` are created automatically.
- **Privacy:** FFmpeg processing is local. Whisper inference is local after model download; `pip` installation and first model download require internet access. Observe course copyrights and platform rules.

## Troubleshooting

- `ffmpeg: command not found`: install FFmpeg and ensure it is in your `PATH`.
- `Unknown encoder`: check `ffmpeg -encoders`; install an FFmpeg build with the listed encoder.
- `No such file`: confirm `INPUT` is correct and quote paths containing spaces.
- Whisper too slow: use `MODEL=tiny` or `MODEL=base`; CPU processing can be much slower than the clip duration.
- Whisper text is wrong: select correct `LANG`, use clearer audio, or choose a larger model.
- `File exists`: pick another `OUTDIR` / `OUTPUT`, or explicitly set `OVERWRITE=1`.
- `make clean` removes `OUTDIR` only when it is a safe directory inside this repository; it refuses project source, configuration directories, root/parent paths, and symlinks. Keep media files outside `OUTDIR`.

## Development

```sh
make test
make help
```

Only Python's standard library is used by the JSON clip helper and tests. FFmpeg is invoked without a shell to avoid command injection from filenames. There are no tracked sample media files.

## License

MIT — see [LICENSE](LICENSE).
