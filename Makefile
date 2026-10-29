# Video CLI Toolbox — GNU Make frontend for FFmpeg, ffprobe, Whisper, and yt-dlp.
# Override any setting on the command line: make compress INPUT='movie.mp4' CRF=27
.DEFAULT_GOAL := help
SHELL := /bin/sh
.SHELLFLAGS := -eu -c

FFMPEG ?= ffmpeg
FFPROBE ?= ffprobe
PYTHON ?= python3
VENV ?= .venv
WHISPER := $(VENV)/bin/whisper

INPUT ?= input.mp4
OUTPUT ?=
OUTDIR ?= output
START ?= 00:00:00
DURATION ?= 00:00:30
WIDTH ?= 1280
FPS ?= 12
CRF ?= 25
PRESET ?= medium
AUDIO_BITRATE ?= 128k
VIDEO_CODEC ?= libx264
AUDIO_CODEC ?= aac
FORMAT ?= mp4
MODEL ?= small
LANG ?= auto
TASK ?= transcribe
CLIPS ?= examples/clips.json
OVERWRITE ?= 0

# Online sources. Pass URL='https://...' explicitly; yt-dlp never downloads a playlist
# unless you select yt-playlist. Keep URLs quoted to protect ? and & characters.
YTDLP ?= yt-dlp
URL ?=
YT_FORMAT ?= bv[ext=mp4]+ba[ext=m4a]/bv+ba/b
YT_BROWSER ?= vivaldi
# Downloads go to the caller's working directory. Wrappers pass this explicitly
# because `make -C` changes CURDIR to the repository root.
YT_OUTDIR ?= $(CURDIR)
YT_CONTAINER ?= mp4
# Vivaldi cookies by default; override YT_BROWSER= to disable.
# Never persist browser cookies to this repository.
YT_COOKIE_ARGS = $(if $(YT_BROWSER),--cookies-from-browser "$(YT_BROWSER)",)
YT_LANG ?= en
YT_SECTION_START ?= 00:00:00
YT_SECTION_END ?= 00:01:00

# Never overwrite by default. Set OVERWRITE=1 to replace output files.
FFLAG := $(if $(filter 1,$(OVERWRITE)),-y,-n)

.PHONY: help doctor install-whisper info compress convert trim audio mp3 wav frames thumbnail gif subtitles extract-subs clips test clean yt-doctor yt-info yt-formats yt-video yt-audio yt-subs yt-auto-subs yt-subs-list yt-playlist yt-section

help: ## List all commands and configurable variables
	@awk 'BEGIN {FS = ":.*## "; printf "Video CLI Toolbox\n\nUsage: make <target> INPUT=... or URL=... [OPTIONS]\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\nExamples:\n  make info INPUT="lecture.mp4"\n  make compress INPUT="lecture.mp4" CRF=28\n  make subtitles INPUT="lecture.mp4" LANG=English MODEL=small\n  make trim INPUT="lecture.mp4" START=00:05:00 DURATION=00:01:30\n  make clips INPUT="lecture.mp4" CLIPS=examples/clips.json\n\nOutput: OUTDIR=output (or OUTPUT=path). OVERWRITE=1 replaces existing files.\n'

doctor: ## Verify installed binaries and their versions
	@command -v "$(FFMPEG)" >/dev/null || { echo 'Missing ffmpeg'; exit 1; }
	@command -v "$(FFPROBE)" >/dev/null || { echo 'Missing ffprobe'; exit 1; }
	@"$(FFMPEG)" -version | head -n 1
	@"$(FFPROBE)" -version | head -n 1
	@"$(PYTHON)" --version
	@if [ -x "$(WHISPER)" ]; then echo 'Whisper: installed'; else echo 'Whisper: not installed (make install-whisper)'; fi

$(WHISPER):
	$(PYTHON) -m venv "$(VENV)"
	"$(VENV)/bin/python" -m pip install --upgrade pip openai-whisper

install-whisper: $(WHISPER) ## Install OpenAI Whisper into an isolated Python environment

info: ## Print video/audio stream details and metadata (ffprobe)
	@"$(FFPROBE)" -v error -show_format -show_streams "$(INPUT)"

compress: ## Re-encode H.264/AAC MP4; higher CRF means smaller, lower quality
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/compressed.mp4))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:v:0 -map 0:a? -c:v "$(VIDEO_CODEC)" -preset "$(PRESET)" -crf "$(CRF)" -c:a "$(AUDIO_CODEC)" -b:a "$(AUDIO_BITRATE)" -movflags +faststart "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/compressed.mp4)"

convert: ## Convert/re-encode video format, FORMAT=mp4|mkv|mov|webm
	@mkdir -p "$(OUTDIR)"
	@case "$(FORMAT)" in mp4|mkv|mov|webm) ;; *) echo 'FORMAT must be mp4, mkv, mov or webm' >&2; exit 2;; esac
	@"$(PYTHON)" scripts/media.py convert --ffmpeg "$(FFMPEG)" --input "$(INPUT)" --output "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/converted.$(FORMAT))" --format "$(FORMAT)" --overwrite "$(OVERWRITE)"

trim: ## Extract accurate clip by time: START=HH:MM:SS DURATION=HH:MM:SS
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.mp4))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -t "$(DURATION)" -map 0:v:0 -map 0:a? -c:v libx264 -preset veryfast -crf 20 -c:a aac "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.mp4)"

audio: ## Extract original audio without re-encoding (MKV/MP4 source -> MKA)
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mka))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -c:a copy "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mka)"

mp3: ## Export audio as MP3, 128 kbps by default
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mp3))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -c:a libmp3lame -b:a "$(AUDIO_BITRATE)" "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mp3)"

wav: ## Export 16 kHz mono PCM WAV (speech recognition compatible)
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.wav))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.wav)"

frames: ## Export JPG frames at FPS=1 etc. Output directory: OUTDIR/frames
	@mkdir -p "$(OUTDIR)/frames"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -vf "fps=$(FPS)" -q:v 3 "$(OUTDIR)/frames/frame_%06d.jpg"

thumbnail: ## Save one screenshot at START=HH:MM:SS
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/thumbnail.jpg))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -frames:v 1 -update 1 "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/thumbnail.jpg)"

gif: ## Make short GIF; START, DURATION, FPS, WIDTH tune size
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.gif))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -t "$(DURATION)" -filter_complex "[0:v]fps=$(FPS),scale=$(WIDTH):-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.gif)"

subtitles: $(WHISPER) ## Transcribe speech to timestamped SRT with local Whisper
	@mkdir -p "$(OUTDIR)"
	@if [ "$(OVERWRITE)" != "1" ] && [ -e "$(OUTDIR)/$(basename $(notdir $(INPUT))).srt" ]; then echo "SRT exists; use OVERWRITE=1" >&2; exit 2; fi
	@"$(WHISPER)" "$(INPUT)" --model "$(MODEL)" $(if $(filter auto,$(LANG)),,--language "$(LANG)") --task "$(TASK)" --output_format srt --output_dir "$(OUTDIR)" --verbose False

extract-subs: ## Extract existing first subtitle stream to SRT (no AI involved)
	@mkdir -p "$(dir $(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/embedded.srt))"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:s:0 -c:s srt "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/embedded.srt)"

clips: ## Extract multiple clips listed in JSON (start + duration, see example)
	@"$(PYTHON)" scripts/media.py clips --ffmpeg "$(FFMPEG)" --input "$(INPUT)" --manifest "$(CLIPS)" --outdir "$(OUTDIR)/clips" --overwrite "$(OVERWRITE)"

test: ## Run unit tests for CLI helper
	@"$(PYTHON)" -m unittest discover -s tests -v

clean: ## Remove generated output, restricted to a directory inside project root
	@"$(PYTHON)" scripts/media.py clean --outdir "$(OUTDIR)"

# yt-dlp commands are optional. URL is required to avoid surprising network calls.
# Downloads go to YT_OUTDIR (current working directory by default); IDs avoid
# collisions. yt-dlp may require FFmpeg to merge streams or convert subtitles/audio.
# Only download content you have permission to access.

yt-doctor: ## Show installed yt-dlp version (optional dependency)
	@command -v "$(YTDLP)" >/dev/null || { echo 'Missing yt-dlp; see README installation section' >&2; exit 1; }
	@"$(YTDLP)" --version

yt-info: ## Print source title, ID, duration and webpage URL without downloading
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --print "%(title)s | %(id)s | %(duration_string)s | %(webpage_url)s" -- "$(URL)"

yt-formats: ## List video/audio formats available at URL
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --list-formats -- "$(URL)"

yt-subs-list: ## List manual and automatic subtitle languages/formats
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --list-subs -- "$(URL)"

yt-video: ## Download one video; select streams with YT_FORMAT
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --no-overwrites --format "$(YT_FORMAT)" --merge-output-format "$(YT_CONTAINER)" -P "$(YT_OUTDIR)" -o '%(title).160B [%(id)s].%(ext)s' -- "$(URL)"

yt-audio: ## Download original best audio stream without re-encoding
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --no-overwrites -f ba -P "$(YT_OUTDIR)" -o '%(title).160B [%(id)s].%(ext)s' -- "$(URL)"
	@printf '\nAudio downloaded without conversion.\nTo convert to MP3 from the project root:\n  make mp3 INPUT="audio.webm"\nReplace audio.webm with your downloaded filename (webm, m4a, etc.).\n\n'

yt-subs: ## Download manual subtitles only, convert to SRT; YT_LANG=en
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --skip-download --no-overwrites --write-subs --sub-langs "$(YT_LANG)" --convert-subs srt -P "$(YT_OUTDIR)" -o '%(title).160B [%(id)s].%(ext)s' -- "$(URL)"

yt-auto-subs: ## Download available manual or auto subtitles, convert to SRT
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --skip-download --no-overwrites --write-subs --write-auto-subs --sub-langs "$(YT_LANG)" --convert-subs srt -P "$(YT_OUTDIR)" -o '%(title).160B [%(id)s].%(ext)s' -- "$(URL)"

yt-playlist: ## Explicitly download a playlist; potentially many files!
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --yes-playlist $(YT_COOKIE_ARGS) --no-overwrites --download-archive "$(YT_OUTDIR)/.yt-dlp-archive.txt" --format "$(YT_FORMAT)" --merge-output-format "$(YT_CONTAINER)" -P "$(YT_OUTDIR)" -o '%(playlist_title).100B/%(playlist_index)s - %(title).160B [%(id)s].%(ext)s' -- "$(URL)"

yt-section: ## Download a time section; YT_SECTION_START and YT_SECTION_END
	@test -n "$(URL)" || { echo 'URL is required' >&2; exit 2; }
	@mkdir -p "$(YT_OUTDIR)"
	@"$(YTDLP)" --no-playlist $(YT_COOKIE_ARGS) --no-overwrites --download-sections "*$(YT_SECTION_START)-$(YT_SECTION_END)" --format "$(YT_FORMAT)" --merge-output-format "$(YT_CONTAINER)" -P "$(YT_OUTDIR)" -o '%(title).160B [%(id)s] section.%(ext)s' -- "$(URL)"
