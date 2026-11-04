"""Monta os recursos da Google Play em prints/ a partir das telas reais.

    flutter test tool/render_store_shots_test.dart
    python tool/store_assets.py

Saída (português em prints/, espanhol em prints/es/):
    icone-512.png                 512 x 512
    grafico-recursos-1024x500.png 1024 x 500
    captura-0N-*.png              1080 x 1920 (9:16)
"""
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "build" / "store_shots"
OUT = ROOT / "prints"
FONTS = Path(os.environ.get("FLUTTER_ROOT", r"C:\Softwares\flutter")) / "bin/cache/artifacts/material_fonts"

# Cores de lib/core/app_theme.dart
BLUE = (3, 48, 101)
PURPLE = (20, 11, 59)
YELLOW = (250, 178, 6)
RED = (229, 57, 28)
INK = (11, 13, 16)
SOFT = (214, 224, 240)

SHOTS_TEXT = {
    "pt": [
        ("01_inicio", "captura-01-inicio.png",
         "Apoio para quem chegou para trabalhar", "Informação clara em português e espanhol."),
        ("02_cartilha", "captura-02-cartilha.png",
         "Conheça seus direitos no trabalho", "Cartilha com orientações e áudio em português."),
        ("03_forum", "captura-03-forum.png",
         "Uma comunidade que acolhe", "Pergunte e compartilhe experiências no fórum."),
        ("04_conversa", "captura-04-conversa.png",
         "Respostas de quem já passou por isso", "E orientação da equipe SENAI."),
        ("05_senai", "captura-05-senai.png",
         "Cursos gratuitos do SENAI", "Veja a capacitação e onde ser atendido."),
    ],
    "es": [
        ("01_inicio", "captura-01-inicio.png",
         "Apoyo para quien llegó a trabajar", "Información clara en español y portugués."),
        ("02_cartilha", "captura-02-cartilha.png",
         "Conoce tus derechos laborales", "Cartilla con orientación y audio en portugués."),
        ("03_forum", "captura-03-forum.png",
         "Una comunidad que acoge", "Pregunta y comparte experiencias en el foro."),
        ("04_conversa", "captura-04-conversa.png",
         "Respuestas de quien ya pasó por eso", "Y orientación del equipo SENAI."),
        ("05_senai", "captura-05-senai.png",
         "Cursos gratuitos del SENAI", "Mira la capacitación y dónde te atienden."),
    ],
}

FEATURE_TEXT = {
    "pt": ("Apoio ao trabalhador migrante", "Cartilha, fórum e cursos SENAI em PT e ES"),
    "es": ("Apoyo al trabajador migrante", "Cartilla, foro y cursos SENAI en ES y PT"),
}


def font(weight: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / f"roboto-{weight}.ttf"), size)


def gradient(size, top, bottom) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size, top)
    px = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        px.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def rounded_mask(size, radius) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def bird() -> Image.Image:
    """Só o pássaro do logo (sem o nome), em fundo branco quadrado."""
    logo = Image.open(ROOT / "assets/images/logo.png").convert("RGBA")
    crop = logo.crop((280, 185, 1220, 1125))
    square = Image.new("RGBA", crop.size, "white")
    square.alpha_composite(crop)
    return square.convert("RGB")


def icon() -> None:
    mark = bird()
    side = round(mark.width / 0.86)  # margem para a máscara redonda da loja
    canvas = Image.new("RGB", (side, side), "white")
    canvas.paste(mark, ((side - mark.width) // 2, (side - mark.height) // 2))
    canvas.resize((512, 512), Image.LANCZOS).save(OUT / "icone-512.png", optimize=True)


def status_bar(screen: Image.Image) -> Image.Image:
    """Barra de status simples do Android nos 24 dp que o render deixou livres."""
    screen = screen.convert("RGB")
    d = ImageDraw.Draw(screen)
    s = screen.width / 392.7  # px por dp
    d.text((24 * s, 12 * s), "9:41", font=font("medium", round(14 * s)), fill=INK, anchor="lm")
    x = screen.width - 24 * s
    d.rounded_rectangle([x - 22 * s, 7 * s, x - 2 * s, 17 * s], 2 * s, outline=INK, width=round(1.5 * s))
    d.rectangle([x - 20 * s, 9 * s, x - 6 * s, 15 * s], fill=INK)
    d.rectangle([x - 2 * s, 10 * s, x, 14 * s], fill=INK)
    cx, cy = x - 36 * s, 17 * s
    for r in (4, 8, 12):
        d.arc([cx - r * s, cy - r * s, cx + r * s, cy + r * s], 225, 315, fill=INK, width=round(2 * s))
    return screen


def wrap(draw, text, fnt, width):
    lines, line = [], ""
    for word in text.split():
        test = f"{line} {word}".strip()
        if draw.textlength(test, font=fnt) <= width:
            line = test
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def capture(src: Path, dst: Path, title: str, subtitle: str) -> None:
    W, H = 1080, 1920
    canvas = gradient((W, H), BLUE, PURPLE)
    d = ImageDraw.Draw(canvas)
    d.rectangle([W / 2 - 60, 84, W / 2 + 60, 92], fill=YELLOW)

    title_font, sub_font = font("bold", 72), font("regular", 40)
    y = 130
    for line in wrap(d, title, title_font, W - 160):
        d.text((W / 2, y), line, font=title_font, fill="white", anchor="ma")
        y += 88
    y += 16
    for line in wrap(d, subtitle, sub_font, W - 200):
        d.text((W / 2, y), line, font=sub_font, fill=SOFT, anchor="ma")
        y += 54

    # Celular: tela real dentro de uma moldura escura, cortada embaixo.
    screen = status_bar(Image.open(src))
    phone_w = 820
    scale = phone_w / screen.width
    screen = screen.resize((phone_w, round(screen.height * scale)), Image.LANCZOS)
    bezel = 22
    top = 500  # fixo: alinha as capturas lado a lado na loja
    frame = Image.new("RGB", (phone_w + 2 * bezel, screen.height + 2 * bezel), INK)
    frame.paste(screen, (bezel, bezel), rounded_mask(screen.size, 52))
    x = (W - frame.width) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 6, top + 18, x + frame.width + 6, top + frame.height + 18], 74, fill=(0, 0, 0, 90)
    )
    canvas.paste(shadow, (0, 0), shadow)
    canvas.paste(frame, (x, top), rounded_mask(frame.size, 74))
    canvas.save(dst, optimize=True)


def feature_graphic(dst: Path, tagline: str, detail: str) -> None:
    W, H = 1024, 500
    canvas = gradient((W, H), BLUE, PURPLE)
    d = ImageDraw.Draw(canvas)
    # Faixa com as cores do logo.
    for i, color in enumerate((YELLOW, BLUE, RED)):
        d.rectangle([0, H - 12 + i * 4, W, H - 8 + i * 4], fill=color)
    side = 280
    card = Image.new("RGB", (side, side), "white")
    mark = bird().resize((side - 36, side - 36), Image.LANCZOS)
    card.paste(mark, (18, 18))
    top = (H - side) // 2 - 6
    canvas.paste(card, (80, top), rounded_mask(card.size, 36))
    tx = 410
    d.text((tx, 128), "Venexus", font=font("black", 100), fill="white")
    d.rectangle([tx + 4, 254, tx + 84, 260], fill=YELLOW)
    d.text((tx + 2, 284), tagline, font=font("medium", 36), fill="white")
    d.text((tx + 2, 340), detail, font=font("regular", 26), fill=SOFT)
    canvas.save(dst, optimize=True)


def main() -> None:
    for lang, items in SHOTS_TEXT.items():
        out = OUT if lang == "pt" else OUT / lang
        out.mkdir(parents=True, exist_ok=True)
        feature_graphic(out / "grafico-recursos-1024x500.png", *FEATURE_TEXT[lang])
        for src, dst, title, subtitle in items:
            capture(SHOTS / lang / f"{src}.png", out / dst, title, subtitle)
    icon()
    for f in sorted(OUT.rglob("*.png")):
        with Image.open(f) as im:
            print(f"{f.relative_to(OUT)}: {im.size[0]}x{im.size[1]}, {f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
