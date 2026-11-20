"""Tiny map renderer for the map-quiz decks (Pillow + numpy, no GIS libraries).

Data: Natural Earth (public domain), https://www.naturalearthdata.com/
Pass the path of the downloaded GeoJSON files via the environment variables
NE_COUNTRIES (ne_10m_admin_0_countries.geojson) and NE_ADMIN1 (ne_10m_admin_1_states_provinces.geojson).
"""
import json
import math

import numpy as np
from PIL import Image, ImageDraw

SEA = (206, 226, 241)
LAND = (234, 231, 224)
BORDER = (255, 255, 255)
TARGET = (230, 83, 62)
TARGET_BORDER = (255, 255, 255)
W, H = 640, 480
SS = 3  # supersampling for smooth edges


class Poly:
    __slots__ = ("key", "ring", "holes", "bbox")

    def __init__(self, key, ring, holes):
        self.key = key
        self.ring = np.array(ring, dtype=float)
        self.holes = [np.array(h, dtype=float) for h in holes]
        self.bbox = (
            self.ring[:, 0].min(), self.ring[:, 1].min(), self.ring[:, 0].max(), self.ring[:, 1].max()
        )

    def area(self):
        x, y = self.ring[:, 0], self.ring[:, 1]
        return abs(0.5 * np.dot(x, np.roll(y, 1)) - 0.5 * np.dot(y, np.roll(x, 1)))


def load_polys(path, key_fn):
    data = json.load(open(path))
    polys = []
    for f in data["features"]:
        key = key_fn(f["properties"])
        g = f["geometry"]
        if g is None:
            continue
        parts = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for part in parts:
            polys.append(Poly(key, part[0], part[1:]))
    return polys


def shifted(poly, wrap):
    """Longitudes shifted into 0..360 for views that cross the antimeridian."""
    ring = poly.ring.copy()
    if wrap:
        ring[ring[:, 0] < 0, 0] += 360
    return ring


class View:
    def __init__(self, lon0, lon1, lat0, lat1, wrap=False, pad=1.55, min_span=9.0, aspect=W / H):
        """Fit the box [lon0,lon1]x[lat0,lat1] into the image with some padding.
        min_span is the smallest visible height in degrees of latitude."""
        self.wrap = wrap
        cy = (lat0 + lat1) / 2
        self.cx = (lon0 + lon1) / 2
        self.cy = cy
        kx = math.cos(math.radians(min(abs(cy), 70)))
        need_h = max((lat1 - lat0) * pad, (lon1 - lon0) * kx * pad / aspect, min_span)
        self.h = need_h
        self.kx = kx
        self.scale = (H * SS) / need_h  # pixels per degree latitude

    def project(self, pts):
        x = (pts[:, 0] - self.cx) * self.kx * self.scale + W * SS / 2
        y = (self.cy - pts[:, 1]) * self.scale + H * SS / 2
        return np.stack([x, y], axis=1)

    def visible(self, bbox, wrap):
        lon0, lat0, lon1, lat1 = bbox
        if wrap:
            if lon0 < 0:
                lon0 += 360
            if lon1 < 0:
                lon1 += 360
            if lon1 < lon0:
                lon1 += 360
        half_w = self.h * (W / H) / self.kx / 2
        half_h = self.h / 2
        return not (
            lon1 < self.cx - half_w or lon0 > self.cx + half_w or lat1 < self.cy - half_h or lat0 > self.cy + half_h
        )


def pixel_extent(view, polys):
    xs = []
    for p in polys:
        pts = view.project(shifted(p, view.wrap))
        xs.append(pts)
    allp = np.concatenate(xs)
    return allp[:, 0].min(), allp[:, 1].min(), allp[:, 0].max(), allp[:, 1].max()


def render(view, polys, targets, ring_if_small=True, line=1.2, fills=None, ring_px=48):
    """polys: every polygon to draw as land. targets: set of keys highlighted."""
    img = Image.new("RGB", (W * SS, H * SS), SEA)
    d = ImageDraw.Draw(img)
    lw = max(1, round(line * SS))
    visible = []
    for p in polys:
        if view.visible(p.bbox, view.wrap):
            visible.append((p, view.project(shifted(p, view.wrap))))
    # land
    for p, pts in visible:
        if p.key not in targets and len(pts) >= 3:
            d.polygon([tuple(q) for q in pts], fill=(fills or {}).get(p.key, LAND))
    # target
    tgt_pts = []
    for p, pts in visible:
        if p.key in targets and len(pts) >= 3:
            d.polygon([tuple(q) for q in pts], fill=TARGET)
            for h in p.holes:
                hp = view.project(shifted(Poly(p.key, h, []), view.wrap))
                d.polygon([tuple(q) for q in hp], fill=LAND)
            tgt_pts.append(pts)
    # borders
    for p, pts in visible:
        if p.key in targets:
            continue
        d.line([tuple(q) for q in pts] + [tuple(pts[0])], fill=BORDER, width=lw, joint="curve")
    for p, pts in visible:
        if p.key in targets:
            d.line([tuple(q) for q in pts] + [tuple(pts[0])], fill=TARGET_BORDER, width=lw, joint="curve")
            for h in p.holes:
                hp = view.project(shifted(Poly(p.key, h, []), view.wrap))
                d.line([tuple(q) for q in hp] + [tuple(hp[0])], fill=BORDER, width=lw)
            # specks of land (atolls, small islands) get a dot so they stay visible
            ext = max(pts[:, 0].max() - pts[:, 0].min(), pts[:, 1].max() - pts[:, 1].min())
            biggest = max(
                max(q[:, 0].max() - q[:, 0].min(), q[:, 1].max() - q[:, 1].min())
                for pp, q in visible
                if pp.key in targets
            )
            if ext < 9 * SS and biggest < 25 * SS:
                cx, cy = pts[:, 0].mean(), pts[:, 1].mean()
                r = 4.2 * SS
                d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=TARGET)
    # ring around tiny targets so they can be found
    if ring_if_small and tgt_pts:
        allp = np.concatenate(tgt_pts)
        x0, y0, x1, y1 = allp[:, 0].min(), allp[:, 1].min(), allp[:, 0].max(), allp[:, 1].max()
        if max(x1 - x0, y1 - y0) < ring_px * SS:
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            r = 22 * SS
            d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=TARGET, width=3 * SS)
    out = img.resize((W, H), Image.LANCZOS)
    return out


def save_png(img, path, colors=48):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    q = img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


def bbox_of(polys, min_share=0.12):
    """Bounding box of the main parts (ignores far-away small islands/territories)."""
    areas = [p.area() for p in polys]
    biggest = max(areas)
    keep = [p for p, a in zip(polys, areas) if a >= biggest * min_share]
    return (
        min(p.bbox[0] for p in keep),
        min(p.bbox[1] for p in keep),
        max(p.bbox[2] for p in keep),
        max(p.bbox[3] for p in keep),
    )
