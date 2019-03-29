# ======================================================================
# Makefile - creates a binary animated GIF from a video clip
# Copyright (C) 2019 John Glenn Neffenger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ======================================================================
SHELL = /bin/bash

# Input files
video = src/Mechanical_Doll_1922.webm
palette = src/binary-palette.png

# Commands
FFMPEG = /snap/bin/ffmpeg
MKBITMAP = mkbitmap
POTRACE = potrace
INKSCAPE = inkscape
CONVERT = convert

# Command options (mkbitmap defaults: -f 4 -s 2 -3 -t 0.45)
MKBITMAP_FLAGS = --filter 16 --scale 2 --cubic --threshold 0.48
POTRACE_FLAGS = --backend svg --resolution 90 --turdsize 4
INKSCAPE_FLAGS = --export-width=800

# Frame rate calculations (original clip is 360 frames at 24 fps)
step := 2
fps := $(shell echo $$((24/$(step))))
delay := $(shell echo $$((100/$(fps))))
frames := $(shell echo $$((15*$(fps))))

# Video filters (looping twirl is at 3:59 frames 196 to 220)
odd := decimate=cycle=5,trim=start_frame=13:end_frame=373
even := decimate=cycle=5,trim=start_frame=12:end_frame=372
speed := framestep=step=$(step),setpts=N/($(fps)*TB)
vignette := vignette=angle=PI/12:mode=backward
scale := scale=800x600:flags=lanczos
dither_none := paletteuse=dither=none
dither_bayer := paletteuse=dither=bayer:bayer_scale=1

# Video processing options
start := -ss 3:59
chain1_odd := $(odd),$(speed),$(vignette),$(scale) [x]
chain1_even := $(even),$(speed),reverse,$(vignette),$(scale) [x]
chain2 := [x][1:v] $(dither_none)
filter_odd := -filter_complex "$(chain1_odd); $(chain2)"
filter_even := -filter_complex "$(chain1_even); $(chain2)"
frames_odd := -filter:v "$(odd),$(speed)"
frames_even := -filter:v "$(even),$(speed)"

# Image processing options
monochrome := -layers flatten -dither None -monochrome -negate
animate := -delay $(delay) -dispose none -loop 0

# Lists of prerequisite files
seq := {001..$(frames)}
ppm_list := $(shell echo odd/frame-$(seq).ppm even/frame-$(seq).ppm)
miff_list := $(shell echo odd/frame-$(seq).miff even/frame-$(seq).miff)

# ======================================================================
# Pattern Rules
# ======================================================================

%.odd.gif: $(video)
	$(FFMPEG) $(start) -i $< -i $(palette) $(filter_odd) -y $@

%.even.gif: $(video)
	$(FFMPEG) $(start) -i $< -i $(palette) $(filter_even) -y $@

%.gif: %.odd.gif %.even.gif
	$(CONVERT) $^ -coalesce $@

%.pbm: %.ppm
	$(MKBITMAP) $(MKBITMAP_FLAGS) --output $@ $<

%.svg: %.pbm
	$(POTRACE) $(POTRACE_FLAGS) --output $@ $<

%.png: %.svg
	$(INKSCAPE) $(INKSCAPE_FLAGS) --export-png=$@ $<

%.miff: %.png
	$(CONVERT) $< $(monochrome) $@

# ======================================================================
# Explicit rules
# ======================================================================

.PHONY: all clean

all: doll-dancing.gif

doll-traced.gif: $(miff_list)
	$(CONVERT) $(animate) $(miff_list) -coalesce $@

$(ppm_list): split_video

split_video: $(video)
	$(FFMPEG) $(start) -i $< $(frames_odd) -y odd/frame-%03d.ppm
	$(FFMPEG) $(start) -i $< $(frames_even) -y even/frame-%03d.ppm
	touch $@

clean:
	rm -f split_video doll-*.gif even/* odd/*
