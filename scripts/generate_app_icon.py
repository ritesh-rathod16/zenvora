import os
from PIL import Image, ImageDraw, ImageFont

def generate_icon():
    os.makedirs("assets/icon", exist_ok=True)
    size = (512, 512)
    img = Image.new("RGBA", size, (15, 15, 30, 255)) # Dark background #0F0F1E
    draw = ImageDraw.Draw(img)

    # Draw outer glowing ring
    draw.ellipse([32, 32, 480, 480], outline=(108, 99, 255, 180), width=12)
    draw.ellipse([64, 64, 448, 448], fill=(26, 26, 46, 255), outline=(0, 210, 255, 200), width=8)

    # Try loading default or drawing bold letter Z
    try:
        font = ImageFont.truetype("arial.ttf", 240)
    except:
        font = ImageFont.load_default()

    # Draw centered Z
    bbox = draw.textbbox((0, 0), "Z", font=font)
    w = bbox[2] - bbox[0]
    h = bbox[3] - bbox[1]
    x = (512 - w) / 2
    y = (512 - h) / 2 - 20

    draw.text((x, y), "Z", fill=(108, 99, 255, 255), font=font)

    icon_path = "assets/icon/app_icon.png"
    img.save(icon_path, "PNG")
    print(f"Generated app icon at {icon_path}")

if __name__ == "__main__":
    generate_icon()
