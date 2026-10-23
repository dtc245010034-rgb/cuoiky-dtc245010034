#!/usr/bin/env python3
"""Sinh ảnh minh họa (PNG) cho sản phẩm và banner trang chủ vào seed/images/.

Chạy: python3 -I scripts/gen-product-images.py
Cần Pillow và font DejaVu Sans (có sẵn trên Ubuntu). Ảnh sinh ra đã được commit nên
chỉ cần chạy lại khi muốn đổi nội dung.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "seed" / "images"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

# slug, tên hiển thị, nhóm, màu trên, màu dưới, hình biểu tượng
PRODUCTS = [
    ("pt-echo-mini", "PT Echo Mini", "Âm thanh", (37, 99, 235), (30, 41, 120), "speaker"),
    ("pt-air-buds", "PT Air Buds", "Âm thanh", (79, 70, 229), (30, 27, 90), "buds"),
    ("pt-soundbar-200", "PT Soundbar 200", "Âm thanh", (14, 116, 144), (8, 47, 73), "bar"),
    ("pt-lumi", "PT Lumi", "Chiếu sáng", (245, 158, 11), (146, 64, 14), "lamp"),
    ("pt-glow", "PT Glow RGB", "Chiếu sáng", (236, 72, 153), (112, 26, 117), "bulb"),
    ("pt-strip-5m", "PT Strip 5m", "Chiếu sáng", (16, 185, 129), (6, 78, 59), "strip"),
    ("pt-plug", "PT Plug", "Phụ kiện", (100, 116, 139), (30, 41, 59), "plug"),
    ("pt-cam-2k", "PT Cam 2K", "Phụ kiện", (239, 68, 68), (127, 29, 29), "cam"),
]


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def icon(d, kind, cx, cy, s):
    white, soft = (255, 255, 255), (255, 255, 255, 90)
    if kind == "speaker":
        d.rounded_rectangle([cx - s * .6, cy - s * .9, cx + s * .6, cy + s * .9], s * .25, outline=white, width=10)
        d.ellipse([cx - s * .35, cy - s * .15, cx + s * .35, cy + s * .55], outline=white, width=10)
        d.ellipse([cx - s * .12, cy - s * .65, cx + s * .12, cy - s * .41], fill=white)
    elif kind == "buds":
        for k in (-1, 1):
            d.ellipse([cx + k * s * .55 - s * .3, cy - s * .5, cx + k * s * .55 + s * .3, cy + s * .1], outline=white, width=10)
            d.rounded_rectangle([cx + k * s * .55 - s * .09, cy + s * .05, cx + k * s * .55 + s * .09, cy + s * .75], s * .08, fill=white)
    elif kind == "bar":
        d.rounded_rectangle([cx - s * 1.2, cy - s * .3, cx + s * 1.2, cy + s * .3], s * .2, outline=white, width=10)
        for i in range(-3, 4):
            d.ellipse([cx + i * s * .28 - 8, cy - 8, cx + i * s * .28 + 8, cy + 8], fill=white)
    elif kind == "lamp":
        d.polygon([(cx - s * .7, cy - s * .1), (cx + s * .7, cy - s * .1), (cx + s * .4, cy - s * .8), (cx - s * .4, cy - s * .8)], outline=white, width=10)
        d.line([cx, cy - s * .1, cx, cy + s * .7], fill=white, width=12)
        d.rounded_rectangle([cx - s * .5, cy + s * .7, cx + s * .5, cy + s * .85], s * .06, fill=white)
    elif kind == "bulb":
        d.ellipse([cx - s * .6, cy - s * .9, cx + s * .6, cy + s * .3], outline=white, width=10)
        d.rounded_rectangle([cx - s * .25, cy + s * .3, cx + s * .25, cy + s * .75], s * .06, outline=white, width=10)
        d.line([cx - s * .15, cy + s * .55, cx + s * .15, cy + s * .55], fill=white, width=8)
    elif kind == "strip":
        for i in range(7):
            x = cx - s * 1.0 + i * s * .33
            d.ellipse([x - 22, cy - 22 + (30 if i % 2 else -30), x + 22, cy + 22 + (30 if i % 2 else -30)], fill=white)
        d.line([cx - s * 1.1, cy, cx + s * 1.1, cy], fill=white, width=6)
    elif kind == "plug":
        d.rounded_rectangle([cx - s * .6, cy - s * .6, cx + s * .6, cy + s * .6], s * .2, outline=white, width=10)
        for k in (-1, 1):
            d.rounded_rectangle([cx + k * s * .2 - 8, cy - s * .3, cx + k * s * .2 + 8, cy + s * .1], 6, fill=white)
        d.arc([cx - s * .25, cy + s * .05, cx + s * .25, cy + s * .45], 0, 180, fill=white, width=8)
    elif kind == "cam":
        d.rounded_rectangle([cx - s * .8, cy - s * .5, cx + s * .8, cy + s * .5], s * .2, outline=white, width=10)
        d.ellipse([cx - s * .32, cy - s * .32, cx + s * .32, cy + s * .32], outline=white, width=10)
        d.ellipse([cx - s * .1, cy - s * .1, cx + s * .1, cy + s * .1], fill=white)
        d.line([cx, cy + s * .5, cx, cy + s * .85], fill=white, width=12)


def product_image(slug, name, cat, top, bottom, kind):
    img = gradient((800, 800), top, bottom)
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([-150, -150, 450, 450], fill=(255, 255, 255, 25))
    d.ellipse([450, 500, 1000, 1050], fill=(255, 255, 255, 20))
    icon(d, kind, 400, 340, 200)
    d.text((400, 640), name, font=ImageFont.truetype(BOLD, 60), fill="white", anchor="mm")
    d.text((400, 710), cat.upper(), font=ImageFont.truetype(REG, 30), fill=(255, 255, 255, 200), anchor="mm")
    img.save(OUT / f"{slug}.png", optimize=True)


def banner():
    img = gradient((1600, 600), (30, 64, 175), (15, 23, 42))
    d = ImageDraw.Draw(img, "RGBA")
    d.ellipse([1000, -200, 1800, 600], fill=(255, 255, 255, 22))
    d.ellipse([-200, 300, 500, 900], fill=(255, 255, 255, 18))
    d.text((90, 210), "PhucTech Smart Home", font=ImageFont.truetype(BOLD, 76), fill="white", anchor="lm")
    d.text((90, 320), "Âm thanh · Chiếu sáng · Phụ kiện nhà thông minh", font=ImageFont.truetype(REG, 40), fill=(226, 232, 240), anchor="lm")
    icon(d, "bulb", 1360, 260, 170)
    img.save(OUT / "banner.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for p in PRODUCTS:
        product_image(*p)
    banner()
    print(f"Đã tạo {len(PRODUCTS) + 1} ảnh trong {OUT}")
