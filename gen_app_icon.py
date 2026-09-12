"""Generate the Meritendance app launcher icon (yellow smiley).

Classic smiley: yellow radial-gradient ball with a top gloss highlight,
two black oval eyes and a black smile arc, with a small padding margin
so the ball never touches the icon edge.

Writes every launcher icon size used by the project:
  web/favicon.png, web/icons/Icon-{192,512}.png, maskable variants
  android/app/src/main/res/mipmap-*/ic_launcher.png
  ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png
"""
from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024          # master render size
SS = 4               # supersampling factor for smooth anti-aliasing
INSET = 0.055        # padding margin: ball inset from the icon edge

BALL_TOP = (255, 236, 55)     # warm yellow top
BALL_BOTTOM = (250, 190, 10)  # deeper yellow bottom
GLOSS = (255, 250, 200)       # soft top highlight
BLACK = (20, 20, 20)


def render(w):
    """Render the smiley at size w (supersampled by SS)."""
    W = w * SS
    img = Image.new('RGB', (W, W), (255, 255, 255))
    d = ImageDraw.Draw(img)

    m = round(W * INSET)
    d.ellipse((m, m, W - m, W - m), fill=BALL_BOTTOM)

    # Vertical yellow gradient clipped to the ball.
    grad = Image.new('L', (W, W), 0)
    gd = ImageDraw.Draw(grad)
    gd.ellipse((m, m, W - m, W - m), fill=255)
    vgrad = Image.new('RGB', (W, W), BALL_BOTTOM)
    vp = vgrad.load()
    for y in range(W):
        t = y / W
        c = tuple(round(BALL_TOP[i] + (BALL_BOTTOM[i] - BALL_TOP[i]) * t)
                  for i in range(3))
        for x in range(W):
            vp[x, y] = c
    img = Image.composite(vgrad, img, grad)
    d = ImageDraw.Draw(img)

    # Soft gloss highlight in the upper part of the ball.
    gloss = Image.new('L', (W, W), 0)
    gp = ImageDraw.Draw(gloss)
    gm = round(W * 0.16)
    gp.ellipse((gm, round(W * 0.075), W - gm, round(W * 0.52)), fill=110)
    gloss = gloss.filter(ImageFilter.GaussianBlur(W * 0.05))
    white = Image.new('RGB', (W, W), GLOSS)
    img = Image.composite(white, img, gloss)
    d = ImageDraw.Draw(img)

    # Eyes: black vertical ovals.
    ew, eh = W * 0.052, W * 0.115
    ey = W * 0.40
    for ex in (W * 0.405, W * 0.595):
        d.ellipse((ex - ew, ey - eh, ex + ew, ey + eh), fill=BLACK)

    # Smile: thick arc with round caps.
    sw = round(W * 0.055)
    sr = W * 0.185
    scy = W * 0.50
    pts = []
    for i in range(65):
        ang = math.radians(28 + (152 - 28) * i / 64)
        pts.append((W * 0.5 + sr * math.cos(ang), scy + sr * math.sin(ang)))
    for x, y in pts:
        d.ellipse((x - sw / 2, y - sw / 2, x + sw / 2, y + sw / 2), fill=BLACK)

    return img.resize((w, w), Image.LANCZOS)


def write(master, path, size):
    master.resize((size, size), Image.LANCZOS).save(path)
    print('wrote', path, size)


def main():
    master = render(SIZE)

    # Maskable variant: ball shrunk to ~70% and centered so circular /
    # squircle masks on Android home screens never clip it.
    small = render(round(SIZE * 0.70))
    maskable = Image.new('RGB', (SIZE, SIZE), (255, 255, 255))
    off = (SIZE - small.width) // 2
    maskable.paste(small, (off, off))

    write(master, r'I:\Application\meritendance\web\favicon.png', 48)
    write(master, r'I:\Application\meritendance\web\icons\Icon-192.png', 192)
    write(master, r'I:\Application\meritendance\web\icons\Icon-512.png', 512)
    write(maskable, r'I:\Application\meritendance\web\icons\Icon-maskable-192.png', 192)
    write(maskable, r'I:\Application\meritendance\web\icons\Icon-maskable-512.png', 512)

    mip = {'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
           'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192}
    for folder, size in mip.items():
        write(master,
              rf'I:\Application\meritendance\android\app\src\main\res\{folder}\ic_launcher.png',
              size)

    ios = {'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40,
           'Icon-App-20x20@3x.png': 60, 'Icon-App-29x29@1x.png': 29,
           'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
           'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80,
           'Icon-App-40x40@3x.png': 120, 'Icon-App-60x60@2x.png': 120,
           'Icon-App-60x60@3x.png': 180, 'Icon-App-76x76@1x.png': 76,
           'Icon-App-76x76@2x.png': 152, 'Icon-App-83.5x83.5@2x.png': 167,
           'Icon-App-1024x1024@1x.png': 1024}
    for name, size in ios.items():
        write(master,
              rf'I:\Application\meritendance\ios\Runner\Assets.xcassets\AppIcon.appiconset\{name}',
              size)
    print('DONE')


if __name__ == '__main__':
    main()
