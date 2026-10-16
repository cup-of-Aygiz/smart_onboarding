"""Generates monkey_dance.json (Lottie) from simple SVG-like paths.

Run: python3 build_lottie.py
Every layer uses absolute canvas coordinates with anchor == position, so
parenting works without coordinate juggling.
"""
import json
import re

FPS, FRAMES, W, H = 30, 60, 480, 420
# Drawing is authored on a 400px canvas; the rig shifts it to the center.
DX = (W - 400) // 2


def hexc(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)] + [1]


FUR, FUR_DARK, FUR_SHADE = '#BA581F', '#96421A', '#7A3311'
SKIN, PALM, PALM_LINE = '#F1D3B3', '#DEA77D', '#B87A50'
RING, EYE_WHITE, PUPIL, NOSE, LINE = '#EADBC6', '#F2E6D5', '#24150E', '#D7A57D', '#8E5A3A'


def static(v):
    return {'a': 0, 'k': v}


def anim(keys, dims):
    """keys: [(frame, value)], value scalar or list. Ease in/out."""
    out = []
    for i, (t, v) in enumerate(keys):
        v = v if isinstance(v, list) else [v]
        k = {'t': t, 's': v}
        if i < len(keys) - 1:
            k['i'] = {'x': [0.45] * dims, 'y': [1] * dims}
            k['o'] = {'x': [0.55] * dims, 'y': [0] * dims}
        out.append(k)
    return {'a': 1, 'k': out}


def path(d):
    """Parse M/C/L/Z absolute path into a Lottie shape."""
    tokens = re.findall(r'[MCLZ]|-?\d+\.?\d*', d)
    v, ins, outs = [], [], []
    i, cmd = 0, None
    while i < len(tokens):
        tok = tokens[i]
        if tok in 'MCLZ':
            cmd = tok
            i += 1
            if cmd == 'Z':
                continue
            continue
        nums = lambda n: [float(x) for x in tokens[i:i + n]]
        if cmd == 'M':
            x, y = nums(2); i += 2
            v.append([x, y]); ins.append([0, 0]); outs.append([0, 0])
            cmd = 'L'
        elif cmd == 'L':
            x, y = nums(2); i += 2
            v.append([x, y]); ins.append([0, 0]); outs.append([0, 0])
        elif cmd == 'C':
            c1x, c1y, c2x, c2y, x, y = nums(6); i += 6
            px, py = v[-1]
            outs[-1] = [c1x - px, c1y - py]
            v.append([x, y]); ins.append([c2x - x, c2y - y]); outs.append([0, 0])
    closed = 'Z' in d
    if closed and len(v) > 1 and abs(v[0][0] - v[-1][0]) < .01 and abs(v[0][1] - v[-1][1]) < .01:
        # Merge duplicated end point into the start.
        ins[0] = ins[-1]
        v.pop(); ins.pop(); outs.pop()
    return {'ty': 'sh', 'ks': static({'i': ins, 'o': outs, 'v': v, 'c': closed})}


def ellipse(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return {'ty': 'el', 'p': static([cx, cy]), 's': static([rx * 2, ry * 2])}


def fill(color, opacity=100):
    return {'ty': 'fl', 'c': static(hexc(color)), 'o': static(opacity), 'r': 1}


def stroke(color, width, opacity=100):
    return {'ty': 'st', 'c': static(hexc(color)), 'o': static(opacity),
            'w': static(width), 'lc': 2, 'lj': 2}


def group(name, shape, paint):
    tr = {'ty': 'tr', 'p': static([0, 0]), 'a': static([0, 0]), 's': static([100, 100]),
          'r': static(0), 'o': static(100), 'sk': static(0), 'sa': static(0)}
    shapes = shape if isinstance(shape, list) else [shape]
    return {'ty': 'gr', 'nm': name, 'it': shapes + [paint, tr]}


def layer(ind, name, pivot, items, parent=None, rot=None, pos=None, scale=None, null=False):
    ks = {
        'o': static(100),
        'r': rot or static(0),
        'p': pos or static(pivot + [0]),
        'a': static(pivot + [0]),
        's': scale or static([100, 100, 100]),
    }
    lay = {'ddd': 0, 'ind': ind, 'ty': 3 if null else 4, 'nm': name, 'sr': 1, 'ks': ks,
           'ao': 0, 'ip': 0, 'op': FRAMES, 'st': 0, 'bm': 0}
    if parent:
        lay['parent'] = parent
    if not null:
        # items are given bottom-to-top; Lottie draws the first item on top.
        lay['shapes'] = list(reversed(items))
    return lay


# ---------- geometry (same as the SVG) ----------

arm_left = [
    group('arm', path('M132 198 C 88 212 50 275 46 335 C 45 356 80 360 86 342 C 92 296 112 258 152 232 Z'), fill(FUR_DARK)),
    group('hand', path('M40 336 C 28 350 32 374 52 380 C 68 385 90 380 94 364 C 97 350 86 336 70 335 Z'), fill(PALM)),
    group('fingers', [path('M50 364 C 56 369 64 371 72 370'), path('M56 352 C 62 357 70 359 80 357')], stroke(PALM_LINE, 2.5)),
]
arm_right = [
    group('arm', path('M268 198 C 312 212 350 275 354 335 C 355 356 320 360 314 342 C 308 296 288 258 248 232 Z'), fill(FUR_DARK)),
    group('hand', path('M360 336 C 372 350 368 374 348 380 C 332 385 310 380 306 364 C 303 350 314 336 330 335 Z'), fill(PALM)),
    group('fingers', [path('M350 364 C 344 369 336 371 328 370'), path('M344 352 C 338 357 330 359 320 357')], stroke(PALM_LINE, 2.5)),
]
body = [
    group('body', path('M200 175 C 270 175 300 235 298 300 C 296 350 260 378 200 378 C 140 378 104 350 102 300 C 100 235 130 175 200 175 Z'), fill(FUR)),
    group('belly', ellipse(200, 292, 52, 58), fill('#D97A36', 30)),
    group('arm shadow L', path('M150 232 C 118 262 104 300 100 345'), stroke(FUR_SHADE, 10, 35)),
    group('arm shadow R', path('M250 232 C 282 262 296 300 300 345'), stroke(FUR_SHADE, 10, 35)),
    group('leg L', path('M110 330 C 90 350 95 385 135 388 C 170 390 185 370 175 345 Z'), fill(FUR_DARK)),
    group('leg R', path('M290 330 C 310 350 305 385 265 388 C 230 390 215 370 225 345 Z'), fill(FUR_DARK)),
    group('foot L', ellipse(128, 388, 34, 16), fill(PALM)),
    group('foot R', ellipse(272, 388, 34, 16), fill(PALM)),
]
head = [
    group('ear L', ellipse(116, 132, 20), fill(FUR_DARK)),
    group('ear R', ellipse(284, 132, 20), fill(FUR_DARK)),
    group('ear in L', ellipse(117, 133, 11), fill(SKIN)),
    group('ear in R', ellipse(283, 133, 11), fill(SKIN)),
    group('head', path('M200 48 L 210 34 L 214 52 L 228 40 L 228 58 C 268 66 285 100 283 135 C 281 178 248 205 200 205 '
                       'C 152 205 119 178 117 135 C 115 100 132 66 172 58 L 172 40 L 186 52 L 190 34 Z'), fill(FUR)),
    group('brow', path('M150 112 C 160 92 240 92 250 112 C 238 104 162 104 150 112 Z'), fill('#9E4517', 60)),
    group('muzzle', path('M200 130 C 240 130 252 158 246 176 C 240 196 222 202 200 202 C 178 202 160 196 154 176 C 148 158 160 130 200 130 Z'), fill(SKIN)),
    group('ring L', ellipse(170, 118, 22), fill(RING)),
    group('ring R', ellipse(230, 118, 22), fill(RING)),
    group('nose', path('M188 150 C 192 140 208 140 212 150 C 214 158 186 158 188 150 Z'), fill(NOSE)),
    group('nostril L', ellipse(195, 152, 2.4), fill(LINE)),
    group('nostril R', ellipse(205, 152, 2.4), fill(LINE)),
    group('mouth', path('M178 172 C 186 196 214 196 222 172 Z'), fill('#6B3420')),
    group('tongue', path('M188 186 C 194 192 206 192 212 186 C 206 182 194 182 188 186 Z'), fill('#E07A6E')),
]
eyes = [
    group('white L', ellipse(170, 118, 14), fill(EYE_WHITE)),
    group('white R', ellipse(230, 118, 14), fill(EYE_WHITE)),
    group('pupil L', ellipse(171, 119, 8.5), fill(PUPIL)),
    group('pupil R', ellipse(231, 119, 8.5), fill(PUPIL)),
    group('shine L', ellipse(174, 115, 2.8), fill('#FFFFFF')),
    group('shine R', ellipse(234, 115, 2.8), fill('#FFFFFF')),
]
shadow = [group('shadow', ellipse(200, 396, 150, 14), fill('#000000', 18))]

# ---------- animation ----------
# Beats on frames 0, 15, 30, 45: bounce down on each beat.
bounce = anim([(0, [200 + DX, 380, 0]), (7, [200 + DX, 364, 0]), (15, [200 + DX, 380, 0]), (22, [200 + DX, 364, 0]),
               (30, [200 + DX, 380, 0]), (37, [200 + DX, 364, 0]), (45, [200 + DX, 380, 0]), (52, [200 + DX, 364, 0]),
               (60, [200 + DX, 380, 0])], 3)
squash = anim([(0, [105, 95, 100]), (7, [97, 104, 100]), (15, [105, 95, 100]), (22, [97, 104, 100]),
               (30, [105, 95, 100]), (37, [97, 104, 100]), (45, [105, 95, 100]), (52, [97, 104, 100]),
               (60, [105, 95, 100])], 3)
sway = anim([(0, -6), (30, 6), (60, -6)], 1)
head_bob = anim([(0, 7), (15, -7), (30, 7), (45, -7), (60, 7)], 1)
arm_l = anim([(0, 10), (15, 135), (30, 10), (45, -8), (60, 10)], 1)
arm_r = anim([(0, -10), (15, 8), (30, -10), (45, -135), (60, -10)], 1)
blink = anim([(0, [100, 100, 100]), (48, [100, 100, 100]), (51, [100, 8, 100]),
              (54, [100, 100, 100]), (60, [100, 100, 100])], 3)
shadow_scale = anim([(0, [100, 100, 100]), (7, [85, 85, 100]), (15, [100, 100, 100]), (22, [85, 85, 100]),
                     (30, [100, 100, 100]), (37, [85, 85, 100]), (45, [100, 100, 100]), (52, [85, 85, 100]),
                     (60, [100, 100, 100])], 3)

# Layer list: first = top.
layers = [
    layer(1, 'eyes', [200, 118], eyes, parent=3, scale=blink),
    layer(2, 'body shapes', [200, 380], body, parent=6),
    layer(3, 'head', [200, 200], head, parent=6, rot=head_bob),
    layer(4, 'arm left', [138, 210], arm_left, parent=6, rot=arm_l),
    layer(5, 'arm right', [262, 210], arm_right, parent=6, rot=arm_r),
    layer(6, 'rig', [200, 380], [], null=True, pos=bounce, rot=sway, scale=squash),
    layer(7, 'shadow', [200, 396], shadow, pos=static([200 + DX, 396, 0]), scale=shadow_scale),
]
# Head must be drawn above body but below eyes; body above arms.
order = {1: 0, 3: 1, 2: 2, 4: 3, 5: 4, 6: 5, 7: 6}
layers.sort(key=lambda l: order[l['ind']])

lottie = {'v': '5.7.4', 'fr': FPS, 'ip': 0, 'op': FRAMES, 'w': W, 'h': H,
          'nm': 'monkey dance', 'ddd': 0, 'assets': [], 'layers': layers}

with open('monkey_dance.json', 'w') as f:
    json.dump(lottie, f, separators=(',', ':'))
print('monkey_dance.json written,', len(layers), 'layers')

# Local preview page (JSON is inlined because browsers block fetch() on file://).
# Open preview.html in a browser; add ?frame=N to freeze a frame.
with open('preview.html', 'w') as f:
    f.write('''<!doctype html><html><head><meta charset="utf-8"><title>Monkey mascot</title>
<style>body{margin:0;background:#1f2a44;color:#fff;font:14px sans-serif;display:flex;gap:24px;
flex-wrap:wrap;justify-content:center;align-items:flex-end;padding:24px}
figure{margin:0;text-align:center}#anim{width:480px;height:420px}</style></head><body>
<figure><img src="monkey_sitting.svg" width="320"><figcaption>monkey_sitting.svg</figcaption></figure>
<figure><img src="monkey_pointing.svg" width="352"><figcaption>monkey_pointing.svg</figcaption></figure>
<figure><div id="anim"></div><figcaption>monkey_dance.json</figcaption></figure>
<script src="https://cdnjs.cloudflare.com/ajax/libs/lottie-web/5.12.2/lottie.min.js"></script>
<script>const data=''' + json.dumps(lottie) + ''';
const a=lottie.loadAnimation({container:document.getElementById('anim'),renderer:'svg',loop:true,autoplay:true,animationData:data});
const f=new URLSearchParams(location.search).get('frame');if(f!==null){a.goToAndStop(+f,true);}
</script></body></html>''')
print('preview.html written')
