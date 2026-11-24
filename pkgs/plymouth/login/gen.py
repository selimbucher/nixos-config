# gen.py OUT WALLPAPER FONT: draws the login theme's images, one set per scale
# step (NAME-STEP.png) at exact pixel sizes, so the script never resizes them.
# Shapes are drawn 4x too large and reduced. Sizes are in units of a 1080-line
# display; step 175 = 1.75 device pixels per unit. The layout numbers must match
# login.script.
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT, WALL, FONT = sys.argv[1:4]
STEPS = [100, 125, 150, 175, 200, 225, 250]
K = 4  # supersampling

PILL_W, PILL_H, PILL_DY = 176, 28, 165
AVATAR_D, RING_D = 58, 72
INITIALS = "SB"


def canvas_for(step):
    # the glass is baked for the canvas behind it: the laptop panel at its step,
    # a 3:2 display of that scale otherwise
    return (2880, 1920) if step == 175 else (round(1620 * step / 100), round(1080 * step / 100))


def px(v, u):
    return int(v * u + 0.5)


def ss(w, h, fn):
    im = Image.new("RGBA", (w * K, h * K), (0, 0, 0, 0))
    fn(ImageDraw.Draw(im), K)
    return im.resize((w, h), Image.LANCZOS)


def rr_mask(w, h, r):
    m = Image.new("L", (w * K, h * K), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * K - 1, h * K - 1), r * K, fill=255)
    return m.resize((w, h), Image.LANCZOS)


def background(cw, ch):
    im = Image.open(WALL).convert("RGB")
    f = max(cw / im.width, ch / im.height)
    im = im.resize((round(im.width * f), round(im.height * f)), Image.LANCZOS)
    l, t = (im.width - cw) // 2, (im.height - ch) // 2
    a = np.asarray(im.crop((l, t, l + cw, t + ch)), dtype=np.float32)
    # dimmed, more towards the bottom and at the very top
    y = np.linspace(0, 1, ch, dtype=np.float32)[:, None, None]
    shade = 0.82 - 0.30 * np.clip((y - 0.55) / 0.45, 0, 1) ** 1.4 - 0.12 * np.clip((0.18 - y) / 0.18, 0, 1)
    return Image.fromarray(np.clip(a * shade, 0, 255).astype(np.uint8))


def frosted(im, box, sigma):
    # the part of im under box, blurred (3 sigma of margin is all the blur reaches),
    # more colourful and lighter
    x, y, w, h = box
    m = 3 * sigma
    b = im.crop((x - m, y - m, x + w + m, y + h + m)).filter(ImageFilter.GaussianBlur(sigma))
    a = np.asarray(b.crop((m, m, m + w, m + h)), dtype=np.float32)
    lum = (a * [0.2126, 0.7152, 0.0722]).sum(axis=2, keepdims=True)
    a = lum + (a - lum) * 1.6
    a = a * 0.92 + 255 * 0.07
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def glass(fr, r, tint, rim_top, rim_bottom):
    w, h = fr.size
    g = Image.alpha_composite(fr.convert("RGBA"), Image.new("RGBA", (w, h), tint))
    # hairline rim, brighter at the top
    ring = Image.new("L", (w * K, h * K), 0)
    d = ImageDraw.Draw(ring)
    d.rounded_rectangle((0, 0, w * K - 1, h * K - 1), r * K, fill=255)
    b = K
    d.rounded_rectangle((b, b, w * K - 1 - b, h * K - 1 - b), r * K - b, fill=0)
    ring = np.asarray(ring.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255
    grad = np.linspace(rim_top, rim_bottom, h, dtype=np.float32)[:, None]
    a = np.asarray(g, dtype=np.float32)
    k = (ring * grad)[..., None]
    a[..., :3] = a[..., :3] * (1 - k) + 255 * k
    g = Image.fromarray(a.astype(np.uint8))
    g.putalpha(rr_mask(w, h, r))
    return g


def padlock(s, color):
    # shackle and rounded body, s = height in px
    w = round(s * 0.80)

    def fn(d, k):
        S, W = s * k, w * k
        bh = S * 0.58
        sw = S * 0.12
        sx = W * 0.5
        sr = W * 0.30  # shackle radius to the stroke centre
        top = sw / 2
        shackle = (sx - sr - sw / 2, top - sw / 2, sx + sr + sw / 2, top + 2 * sr + sw / 2)
        d.arc(shackle, 180, 360, fill=color, width=round(sw))
        d.rectangle((sx - sr - sw / 2, top + sr, sx - sr + sw / 2, S - bh + 2), fill=color)
        d.rectangle((sx + sr - sw / 2, top + sr, sx + sr + sw / 2, S - bh + 2), fill=color)
        d.rounded_rectangle((0, S - bh, W - 1, S - 1), S * 0.12, fill=color)

    return ss(w, s, fn)


def avatar(u):
    # kiwi's purple, lit from the top, the initials, a soft shadow under it
    D, M = px(AVATAR_D, u), px(10, u)
    T = D + 2 * M
    im = Image.new("RGBA", (T * K, T * K), (0, 0, 0, 0))
    sh = Image.new("L", (T * K, T * K), 0)
    ImageDraw.Draw(sh).ellipse((M * K, (M + px(3, u)) * K, (M + D) * K, (M + D + px(3, u)) * K), fill=110)
    im.putalpha(sh.filter(ImageFilter.GaussianBlur(px(5, u) * K)))
    g = np.zeros((D * K, D * K, 4), np.float32)
    yy = np.linspace(0, 1, D * K, dtype=np.float32)[:, None, None]
    top, bottom = np.array([178, 160, 236]), np.array([104, 82, 186])
    g[..., :3] = top * (1 - yy) + bottom * yy
    g[..., 3] = 255
    disc = Image.fromarray(g.astype(np.uint8))
    m = Image.new("L", (D * K, D * K), 0)
    ImageDraw.Draw(m).ellipse((0, 0, D * K - 1, D * K - 1), fill=255)
    disc.putalpha(m)
    d = ImageDraw.Draw(disc)
    font = ImageFont.truetype(FONT, round(D * 0.38 * K))
    d.text((D * K / 2, D * K / 2 + D * K * 0.01), INITIALS, font=font, fill=(255, 255, 255, 250), anchor="mm")
    d.ellipse((0, 0, D * K - 1, D * K - 1), outline=(255, 255, 255, 46), width=K)
    im.alpha_composite(disc, (M * K, M * K))
    return im.resize((T, T), Image.LANCZOS)


def arrow(u):
    # a light disc with a dark arrow
    A = px(20, u)

    def fn(d, k):
        d.ellipse((0, 0, A * k - 1, A * k - 1), fill=(255, 255, 255, 215))
        c, s, w = A * k / 2, A * k * 0.24, max(2, round(A * k * 0.095))
        col = (40, 32, 64, 255)
        d.line((c - s, c, c + s, c), fill=col, width=w)
        d.line((c + s * 0.15, c - s * 0.85, c + s + w * 0.2, c + w * 0.1), fill=col, width=w)
        d.line((c + s * 0.15, c + s * 0.85, c + s + w * 0.2, c - w * 0.1), fill=col, width=w)

    return ss(A, A, fn)


def ring(u):
    # spinner round the avatar: faint circle, bright arc with round ends
    R, sw = px(RING_D, u), max(2, px(2.4, u))

    def fn(d, k):
        m = sw * k / 2 + k
        d.ellipse((m, m, R * k - m, R * k - m), outline=(255, 255, 255, 46), width=sw * k)
        d.arc((m, m, R * k - m, R * k - m), 270, 350, fill=(255, 255, 255, 255), width=sw * k)
        rr = (R * k - 2 * m) / 2
        for ang in (270, 350):
            a = math.radians(ang)
            cx, cy = R * k / 2 + rr * math.cos(a), R * k / 2 + rr * math.sin(a)
            cap = sw * k / 2
            d.ellipse((cx - cap, cy - cap, cx + cap, cy + cap), fill=(255, 255, 255, 255))

    return ss(R, R, fn)


def main():
    # the wallpaper is stored at half size (1 MB instead of 5) and enlarged once by
    # the script; the glass is cut from the same enlargement so it lines up
    cw, ch = canvas_for(175)
    half = background(cw, ch).resize((cw // 2, ch // 2), Image.LANCZOS)
    half.save(f"{OUT}/bg.png", optimize=True)
    for step in STEPS:
        u = step / 100
        cw, ch = canvas_for(step)
        f = max(cw / half.width, ch / half.height)
        size = (max(cw, int(half.width * f + 0.5)), max(ch, int(half.height * f + 0.5)))
        big = half.resize(size, Image.BILINEAR)
        l, t = int(big.width / 2 - cw / 2), int(big.height / 2 - ch / 2)
        pw, ph = px(PILL_W, u), px(PILL_H, u)
        box = (l + int(cw / 2 - pw / 2), t + int(ch / 2 + px(PILL_DY, u) - ph / 2), pw, ph)
        pill = glass(frosted(big, box, px(26, u)), ph / 2, (255, 255, 255, 34), 0.34, 0.12)
        pill.save(f"{OUT}/pill-{step}.png")
        avatar(u).save(f"{OUT}/avatar-{step}.png")
        padlock(px(19, u), (255, 255, 255, 235)).save(f"{OUT}/lock-{step}.png")
        arrow(u).save(f"{OUT}/arrow-{step}.png")
        d = px(6, u)
        dot = ss(d, d, lambda dr, k: dr.ellipse((0, 0, d * k - 1, d * k - 1), fill=(255, 255, 255, 255)))
        dot.save(f"{OUT}/dot-{step}.png")
        ring(u).save(f"{OUT}/ring-{step}.png")


main()
