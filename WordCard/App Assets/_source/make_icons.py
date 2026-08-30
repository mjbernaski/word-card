#!/usr/bin/env python3
"""Cut a full Valence icon set from one source photo.

Usage: make_icons.py <source-image> [--dry-run <outdir>]

Writes into WordCard/App Assets/{iOS,macOS,tvOS,visionOS}/*.xcassets, or, with
--dry-run, into a scratch directory for review before anything is replaced.
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont
import numpy as np

PROJECT = "/Users/michaelbernaski/Documents/word-card"
CATALOGS = os.path.join(PROJECT, "WordCard/App Assets")

FONT = "/System/Library/Fonts/SFNS.ttf"
WORDMARK = "VALENCE"
INK = (255, 246, 216)          # warm white, picked out of the fireflies
SS = 4                          # supersampling factor for masks


# ---------------------------------------------------------------- source crop
def square_crop(img, bias_y=0.5):
    """Center crop to a square, favouring the middle of the frame."""
    w, h = img.size
    s = min(w, h)
    left = (w - s) // 2
    top = int(round((h - s) * bias_y))
    return img.crop((left, top, left + s, top + s))


def wide_crop(img, ratio):
    """Center band at the requested aspect ratio (for tvOS)."""
    w, h = img.size
    if w / h > ratio:
        nw, nh = int(round(h * ratio)), h
    else:
        nw, nh = w, int(round(w / ratio))
    return img.crop(((w - nw) // 2, (h - nh) // 2, (w - nw) // 2 + nw, (h - nh) // 2 + nh))


# ------------------------------------------------------------------- wordmark
def draw_wordmark(img, height_frac=0.085, baseline_frac=0.80, tracking_frac=0.16,
                  scrim=True):
    """Set WORDMARK across the lower third, letterspaced, over a soft scrim.

    The photo is busy, so the text gets a vertical scrim behind it rather than a
    drop shadow -- a shadow reads as grime at 32px, a scrim just darkens.
    """
    W, H = img.size
    size = max(8, int(H * height_frac))
    try:
        font = ImageFont.truetype(FONT, size)
        try:                      # SFNS is variable; nudge toward a lighter weight
            font.set_variation_by_axes([340])
        except Exception:
            pass
    except OSError:
        font = ImageFont.load_default()

    tracking = size * tracking_frac
    widths = [font.getbbox(c)[2] - font.getbbox(c)[0] for c in WORDMARK]
    advances = [font.getlength(c) for c in WORDMARK]
    total = sum(advances) + tracking * (len(WORDMARK) - 1)

    ascent, descent = font.getmetrics()
    baseline = H * baseline_frac

    # scrim: a soft dark band behind the text, feathered top and bottom.
    # A layered icon skips it -- the front layer is transparent by design, and a
    # dark band there would sit over the photo as a grey smear.
    band_top = int(baseline - ascent * 1.5)
    band_bot = int(baseline + descent * 1.5)
    if scrim and band_bot > band_top:
        scrim = Image.new("L", (1, H), 0)
        px = scrim.load()
        for y in range(H):
            if band_top <= y <= band_bot:
                mid = (band_top + band_bot) / 2
                half = max(1.0, (band_bot - band_top) / 2)
                px[0, y] = int(150 * (1 - ((y - mid) / half) ** 2))
        scrim = scrim.resize((W, H))
        img.alpha_composite(Image.merge("RGBA", (
            Image.new("L", (W, H), 0), Image.new("L", (W, H), 0),
            Image.new("L", (W, H), 0), scrim)))

    d = ImageDraw.Draw(img)
    x = (W - total) / 2
    for ch, adv in zip(WORDMARK, advances):
        d.text((x, baseline), ch, font=font, fill=INK + (255,), anchor="ls")
        x += adv + tracking
    return img


def wordmark_layer(w, h, **kw):
    """The wordmark alone on transparency, for a parallax stack's front layer."""
    kw.setdefault("scrim", False)
    return draw_wordmark(Image.new("RGBA", (w, h), (0, 0, 0, 0)), **kw)


# --------------------------------------------------------------- macOS shape
def squircle_mask(size, n=5.0):
    """Superellipse mask approximating the macOS icon shape."""
    N = size * SS
    ax = np.linspace(-1, 1, N)
    xx, yy = np.meshgrid(ax, ax)
    inside = (np.abs(xx) ** n + np.abs(yy) ** n) <= 1.0
    m = Image.fromarray((inside * 255).astype(np.uint8), "L")
    return m.resize((size, size), Image.LANCZOS)


def macos_canvas(art, size=1024, art_frac=0.8046875):
    """Place the art inside the macOS icon grid: 824/1024 of the canvas."""
    side = int(round(size * art_frac))
    tile = art.resize((side, side), Image.LANCZOS).convert("RGBA")
    tile.putalpha(squircle_mask(side))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(tile, ((size - side) // 2, (size - side) // 2))
    return canvas


# Below this pixel size the wordmark is no longer type, just a pale smear, and
# the full swarm collapses into an undifferentiated gold blur. Small sizes get a
# tighter crop and no text instead -- fewer fireflies, but ones you can see.
SMALL_MAX = 64
SMALL_ZOOM = 0.55


def small_master(src):
    sq = square_crop(src)
    s = sq.size[0]
    keep = int(s * SMALL_ZOOM)
    off = (s - keep) // 2
    return sq.crop((off, off, off + keep, off + keep)).resize((1024, 1024), Image.LANCZOS)


# ------------------------------------------------------------------- outputs
MAC_SIZES = [("icon_16x16.png", 16), ("icon_32x32@2x.png", 32),
             ("icon_32x32.png", 32), ("icon_64x64@2x.png", 64),
             ("icon_128x128.png", 128), ("icon_256x256@2x.png", 256),
             ("icon_256x256.png", 256), ("icon_512x512@2x.png", 512),
             ("icon_512x512.png", 512), ("icon_1024x1024@2x.png", 1024)]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src_path = sys.argv[1]
    dry = "--dry-run" in sys.argv
    outroot = sys.argv[sys.argv.index("--dry-run") + 1] if dry else CATALOGS

    src = Image.open(src_path).convert("RGBA")
    print(f"source {src.size[0]}x{src.size[1]}")

    # square master, full bleed. iOS and macOS bake the wordmark in; the
    # layered platforms keep the photo and the wordmark apart, so both a plain
    # plate and a lettered master are needed.
    plate = square_crop(src).resize((1024, 1024), Image.LANCZOS)
    master = draw_wordmark(plate.copy())
    small = small_master(src)

    def out(rel):
        p = os.path.join(outroot, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        return p

    if dry:
        master.save(out("master-1024.png"))
        small.save(out("small-master-1024.png"))
        for px in (16, 32, 64, 128, 256, 1024):
            macos_canvas(small if px <= SMALL_MAX else master, px).save(out(f"macos-{px}.png"))
        tv = wide_crop(src, 400 / 240).resize((1280, 768), Image.LANCZOS)
        draw_wordmark(tv, height_frac=0.13, baseline_frac=0.82).save(out("tvos-1280x768.png"))
        print("dry run written to", outroot)
        return

    # iOS: full bleed, the system applies the mask
    master.convert("RGB").save(out("iOS/iOS.xcassets/AppIcon.appiconset/AppIcon.png"))

    # macOS: squircle and margin baked in, every idiom size
    macdir = "macOS/macOS.xcassets/AppIcon.appiconset"
    for name, px in MAC_SIZES:
        macos_canvas(small if px <= SMALL_MAX else master, px).save(out(f"{macdir}/{name}"))

    # visionOS and tvOS both reject a stack that carries art on only one layer:
    #   error: ... must have at least 2 layers with applicable content.
    # Splitting photo from wordmark satisfies that and is what the parallax is
    # for -- the lettering floats above the swarm instead of being painted on
    # it. Neither back layer gets the wordmark, or it would show up twice.
    vis = "visionOS/visionOS.xcassets/AppIcon.solidimagestack"
    plate.convert("RGB").save(out(
        f"{vis}/Back.solidimagestacklayer/Content.imageset/AppIcon-vision.png"))
    wordmark_layer(1024, 1024).save(out(
        f"{vis}/Front.solidimagestacklayer/Content.imageset/AppIcon-vision-front.png"))

    # tvOS: wide crops for both image stacks
    ba = "tvOS/tvOS.xcassets/AppIcon.brandassets"
    for stack, (w, h), back, front in (
            ("App Icon", (400, 240), "icon_back.png", "icon_front.png"),
            ("App Icon - App Store", (1280, 768),
             "icon_back_store.png", "icon_front_store.png")):
        layers = f"{ba}/{stack}.imagestack"
        tv = wide_crop(src, w / h).resize((w, h), Image.LANCZOS)
        tv.convert("RGB").save(out(
            f"{layers}/Back.imagestacklayer/Content.imageset/{back}"))
        wordmark_layer(w, h, height_frac=0.13, baseline_frac=0.82).save(out(
            f"{layers}/Front.imagestacklayer/Content.imageset/{front}"))

    # Top shelf art is a flat imageset rather than a stack, so the wordmark is
    # baked back in. Both idioms ship 1x and 2x.
    for shelf, (w, h) in (("Top Shelf Image", (1920, 720)),
                          ("Top Shelf Image Wide", (2320, 720))):
        for scale in (1, 2):
            art = wide_crop(src, w / h).resize((w * scale, h * scale), Image.LANCZOS)
            art = draw_wordmark(art, height_frac=0.13, baseline_frac=0.82)
            suffix = "" if scale == 1 else "@2x"
            art.convert("RGB").save(out(
                f"{ba}/{shelf}.imageset/{shelf.lower().replace(' ', '_')}{suffix}.png"))

    print("icon set written")


if __name__ == "__main__":
    main()
