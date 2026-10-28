# Video CLI Toolbox — GNU Make frontend for FFmpeg, ffprobe, and Whisper.
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

# Never overwrite by default. Set OVERWRITE=1 to replace output files.
FFLAG := $(if $(filter 1,$(OVERWRITE)),-y,-n)

.PHONY: help doctor install-whisper info compress convert trim audio mp3 wav frames thumbnail gif subtitles extract-subs clips test clean

help: ## List all commands and configurable variables
	@awk 'BEGIN {FS = ":.*## "; printf "Video CLI Toolbox\n\nUsage: make <target> INPUT=... [OPTIONS]\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
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
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:v:0 -map 0:a? -c:v "$(VIDEO_CODEC)" -preset "$(PRESET)" -crf "$(CRF)" -c:a "$(AUDIO_CODEC)" -b:a "$(AUDIO_BITRATE)" -movflags +faststart "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/compressed.mp4)"

convert: ## Convert/re-encode video format, FORMAT=mp4|mkv|mov|webm
	@mkdir -p "$(OUTDIR)"
	@case "$(FORMAT)" in mp4|mkv|mov|webm) ;; *) echo 'FORMAT must be mp4, mkv, mov or webm' >&2; exit 2;; esac
	@"$(PYTHON)" scripts/media.py convert --ffmpeg "$(FFMPEG)" --input "$(INPUT)" --output "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/converted.$(FORMAT))" --format "$(FORMAT)" --overwrite "$(OVERWRITE)"

trim: ## Extract accurate clip by time: START=HH:MM:SS DURATION=HH:MM:SS
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -t "$(DURATION)" -map 0:v:0 -map 0:a? -c:v libx264 -preset veryfast -crf 20 -c:a aac "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.mp4)"

audio: ## Extract original audio without re-encoding (MKV/MP4 source -> MKA)
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -c:a copy "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mka)"

mp3: ## Export audio as MP3, 128 kbps by default
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -c:a libmp3lame -b:a "$(AUDIO_BITRATE)" "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.mp3)"

wav: ## Export 16 kHz mono PCM WAV (speech recognition compatible)
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:a:0 -vn -ac 1 -ar 16000 -c:a pcm_s16le "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/audio.wav)"

frames: ## Export JPG frames at FPS=1 etc. Output directory: OUTDIR/frames
	@mkdir -p "$(OUTDIR)/frames"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -vf "fps=$(FPS)" -q:v 3 "$(OUTDIR)/frames/frame_%06d.jpg"

thumbnail: ## Save one screenshot at START=HH:MM:SS
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -frames:v 1 -update 1 "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/thumbnail.jpg)"

gif: ## Make short GIF; START, DURATION, FPS, WIDTH tune size
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -ss "$(START)" -i "$(INPUT)" -t "$(DURATION)" -filter_complex "[0:v]fps=$(FPS),scale=$(WIDTH):-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/clip.gif)"

subtitles: $(WHISPER) ## Transcribe speech to timestamped SRT with local Whisper
	@mkdir -p "$(OUTDIR)"
	@"$(WHISPER)" "$(INPUT)" --model "$(MODEL)" $(if $(filter auto,$(LANG)),,--language "$(LANG)") --task "$(TASK)" --output_format srt --output_dir "$(OUTDIR)" --verbose False

extract-subs: ## Extract existing first subtitle stream to SRT (no AI involved)
	@mkdir -p "$(OUTDIR)"
	@"$(FFMPEG)" -hide_banner $(FFLAG) -i "$(INPUT)" -map 0:s:0 -c:s srt "$(if $(OUTPUT),$(OUTPUT),$(OUTDIR)/embedded.srt)"

clips: ## Extract multiple clips listed in JSON (start + duration, see example)
	@"$(PYTHON)" scripts/media.py clips --ffmpeg "$(FFMPEG)" --input "$(INPUT)" --manifest "$(CLIPS)" --outdir "$(OUTDIR)/clips" --overwrite "$(OVERWRITE)"

test: ## Run unit tests for CLI helper
	@"$(PYTHON)" -m unittest discover -s tests -v

clean: ## Delete generated output only (never source media)
	@case "$(OUTDIR)" in ""|"."|".."|"/"|"./"|"../"|"/*"|"~"|"$$HOME"|"$(HOME)") echo "Unsafe OUTDIR for clean" >&2; exit 2;; esac
	@rm -rf -- "$(OUTDIR)"
