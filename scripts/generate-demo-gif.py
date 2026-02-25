#!/usr/bin/env python3
"""Generate the animated demo GIF for Sound of Silence README."""

from PIL import Image, ImageDraw, ImageFont
import os

# ── Dimensions & colors ────────────────────────────────────────────
W, H = 720, 310
TITLE_H = 36
STATUS_H = 34
PAD = 16
LINE_H = 24

# Tokyo Night palette
BG       = "#1a1b26"
TITLE_BG = "#24283b"
STATUS_BG= "#1f2335"
TITLE_FG = "#787c99"
PROMPT_C = "#7aa2f7"
TEXT_C   = "#a9b1d6"
GREEN_C  = "#9ece6a"
RED_C    = "#ff4444"
RED_DIM  = "#661111"
YELLOW_C = "#FFE073"
CYAN_C   = "#47FF9C"
DIM_C    = "#565f89"
CURSOR_C = "#c0caf5"
BADGE_BG = "#292e42"
WHITE_C  = "#e0e0e0"
HIGHLIGHT= "#33467C"

FONT_PATH = "/System/Library/Fonts/Menlo.ttc"
font      = ImageFont.truetype(FONT_PATH, 14)
font_sm   = ImageFont.truetype(FONT_PATH, 11)
font_title= ImageFont.truetype(FONT_PATH, 12)
font_bold = ImageFont.truetype(FONT_PATH, 14)

# ── Drawing helpers ─────────────────────────────────────────────────

def make_frame():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # Title bar
    d.rounded_rectangle([0, 0, W, TITLE_H], radius=10, fill=TITLE_BG)
    d.rectangle([0, 26, W, TITLE_H], fill=TITLE_BG)
    # Traffic lights
    for i, c in enumerate(["#ff5f57", "#febc2e", "#28c840"]):
        cx = 20 + i * 20
        d.ellipse([cx - 6, TITLE_H // 2 - 6, cx + 6, TITLE_H // 2 + 6], fill=c)
    d.text((W // 2, 10), "sound-of-silence demo", fill=TITLE_FG, font=font_title, anchor="mt")
    # Status bar
    d.rectangle([0, H - STATUS_H, W, H], fill=STATUS_BG)
    d.rounded_rectangle([0, H - 10, W, H], radius=10, fill=STATUS_BG)
    return img, d


def prompt_line(d, y, cmd="", show_cursor=False):
    d.text((PAD, y), "~", fill=PROMPT_C, font=font)
    d.text((PAD + 20, y), "$ " + cmd, fill=TEXT_C, font=font)
    if show_cursor and not cmd:
        d.rectangle([PAD + 38, y + 2, PAD + 47, y + 18], fill=CURSOR_C)
    elif show_cursor:
        cx = PAD + 20 + d.textlength("$ " + cmd, font=font) + 4
        d.rectangle([int(cx), y + 2, int(cx) + 9, y + 18], fill=CURSOR_C)
    return y + LINE_H


def text_line(d, y, text, color=TEXT_C):
    d.text((PAD, y), text, fill=color, font=font)
    return y + LINE_H


def cursor_at(d, x, y):
    d.rectangle([x, y + 2, x + 9, y + 18], fill=CURSOR_C)


def status_recording(d, secs, tick):
    sy = H - STATUS_H // 2 - 1
    dots = [".", "..", "...", ""][tick % 4]
    dots_pad = dots.ljust(3)  # fixed width so text doesn't jump
    dot_c = RED_C if tick % 3 != 2 else RED_DIM
    timer = f"{secs // 60}:{secs % 60:02d}"
    label = f"Recording{dots_pad} {timer}"
    # Red dot + label on one line
    d.ellipse([W - 210, sy - 5, W - 198, sy + 7], fill=dot_c)
    d.text((W - 192, sy - 7), "Recording" + dots_pad, fill=WHITE_C, font=font)
    # Timer in cyan right after
    rec_w = d.textlength("Recording" + dots_pad, font=font)
    d.text((W - 192 + int(rec_w) + 4, sy - 7), timer, fill=CYAN_C, font=font_bold)


def status_transcribing(d, dots="..."):
    sy = H - STATUS_H // 2 - 1
    d.text((W - 192, sy - 7), "Transcribing" + dots, fill=YELLOW_C, font=font)


def keybadge(d, label="Cmd+Shift+V", highlight=False):
    sy = H - STATUS_H // 2 - 11
    bg = HIGHLIGHT if highlight else BADGE_BG
    d.rounded_rectangle([12, sy, 130, sy + 22], radius=4, fill=bg)
    d.text((20, sy + 4), label, fill=DIM_C if not highlight else WHITE_C, font=font_sm)


# ── Frame accumulator ──────────────────────────────────────────────
frames = []
durations = []

def add(img, ms):
    frames.append(img.copy())
    durations.append(max(ms // 2, 20))


# ══════════════════════════════════════════════════════════════════════
#  SCENE 1: Idle terminal — blinking cursor
# ══════════════════════════════════════════════════════════════════════
for blink in range(3):
    img, d = make_frame()
    y = TITLE_H + PAD
    if blink % 2 == 0:
        prompt_line(d, y, show_cursor=True)
    else:
        prompt_line(d, y, show_cursor=False)
    add(img, 500)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 2: Cmd+Shift+V pressed — keybadge lights up
# ══════════════════════════════════════════════════════════════════════
img, d = make_frame()
y = TITLE_H + PAD
prompt_line(d, y, show_cursor=True)
keybadge(d, highlight=True)
add(img, 700)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 3: Recording — timer counts up with pulsing dot
# ══════════════════════════════════════════════════════════════════════
for sec in range(6):
    for tick in range(2):  # 2 sub-frames per second for animation
        img, d = make_frame()
        y = TITLE_H + PAD
        prompt_line(d, y, show_cursor=True)
        keybadge(d)
        status_recording(d, sec, sec * 2 + tick)
        add(img, 500)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 4: Cmd+Shift+V again — stop recording
# ══════════════════════════════════════════════════════════════════════
img, d = make_frame()
y = TITLE_H + PAD
prompt_line(d, y, show_cursor=True)
keybadge(d, highlight=True)
status_recording(d, 5, 99)
add(img, 600)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 5: Transcribing...
# ══════════════════════════════════════════════════════════════════════
for i in range(4):
    img, d = make_frame()
    y = TITLE_H + PAD
    prompt_line(d, y, show_cursor=True)
    dots = "." * (i % 3 + 1)
    status_transcribing(d, dots)
    add(img, 500)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 6: Text appears via typewriter
# ══════════════════════════════════════════════════════════════════════
spoken = "Hello, this text was spoken not typed"
# Type in bursts of varying speed for realism
for i in range(0, len(spoken) + 1, 2):
    partial = spoken[:i] if i <= len(spoken) else spoken
    img, d = make_frame()
    y = TITLE_H + PAD
    if partial:
        d.text((PAD, y), partial, fill=GREEN_C, font=font)
        cx = PAD + d.textlength(partial, font=font) + 4
        cursor_at(d, int(cx), y)
    else:
        cursor_at(d, PAD, y)
    add(img, 60)

# ══════════════════════════════════════════════════════════════════════
#  SCENE 7: Final result — full text shown, new prompt
# ══════════════════════════════════════════════════════════════════════
for blink in range(6):
    img, d = make_frame()
    y = TITLE_H + PAD
    text_line(d, y, spoken, GREEN_C)
    y += LINE_H + 4
    prompt_line(d, y, show_cursor=(blink % 2 == 0))
    add(img, 600)

# ── Save ───────────────────────────────────────────────────────────
output = os.path.join(os.path.dirname(os.path.dirname(__file__)), "demo.gif")
frames[0].save(
    output,
    save_all=True,
    append_images=frames[1:],
    duration=durations,
    loop=0,
    optimize=False,  # keep all frames distinct
)
size_kb = os.path.getsize(output) / 1024
print(f"Saved {output}")
print(f"  {len(frames)} frames, {sum(durations)/1000:.1f}s loop, {size_kb:.0f} KB")
