"""录制 moonkml 演示视频。

真实执行 CLI / bench / test 命令，捕获输出，渲染成终端风格画面，
再用 ffmpeg 编码为 MP4（docs/demo.mp4）。

用法：
    python tools/record_demo.py [--ffmpeg PATH] [--fps 24] [--out docs/demo.mp4]
"""

import argparse
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

W, H = 1280, 720
BG = (30, 30, 30)
BAR = (50, 50, 50)
FG = (220, 220, 220)
GREEN = (106, 190, 69)
GRAY = (150, 150, 150)
CYAN = (86, 182, 194)
RED = (232, 106, 106)
YELLOW = (220, 200, 100)

CONSOLAS = r"C:\Windows\Fonts\consola.ttf"
CONSOLAS_BOLD = r"C:\Windows\Fonts\consolab.ttf"
MSYH = r"C:\Windows\Fonts\msyh.ttc"


def font(size, bold=False):
    path = CONSOLAS_BOLD if bold else CONSOLAS
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.truetype("arial.ttf", size)


def cjk_font(size):
    try:
        return ImageFont.truetype(MSYH, size)
    except OSError:
        return font(size)


ASCII_FONT = font(19)
ASCII_BOLD = font(19, bold=True)
CJK_FONT = cjk_font(19)


def draw_mixed(draw, x, y, text, fill, ascii_font=ASCII_FONT, cjk=CJK_FONT):
    """逐字符绘制：ASCII 用等宽字体，其它用中文字体。"""
    cx = x
    for ch in text:
        f = ascii_font if ord(ch) < 128 else cjk
        draw.text((cx, y), ch, font=f, fill=fill)
        cx += f.getlength(ch)
    return cx


def line_width(text, ascii_font=ASCII_FONT, cjk=CJK_FONT):
    total = 0.0
    for ch in text:
        f = ascii_font if ord(ch) < 128 else cjk
        total += f.getlength(ch)
    return total


def base_frame(title="moonkml — demo"):
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 34], fill=BAR)
    for i, color in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse([16 + i * 22, 11, 28 + i * 22, 23], fill=color)
    d.text((110, 9), title, font=font(15), fill=(180, 180, 180))
    return img, d


def wrap(text, limit=96):
    out = []
    cur = ""
    for ch in text:
        cur += ch
        if len(cur) >= limit:
            out.append(cur)
            cur = ""
    if cur:
        out.append(cur)
    return out


class Video:
    def __init__(self, fps):
        self.fps = fps
        self.frames = []

    def hold(self, img, seconds):
        for _ in range(max(1, int(seconds * self.fps))):
            self.frames.append(img.copy())

    def title_card(self, lines, seconds=3.0):
        img, d = base_frame("moonkml — demo")
        y = 250
        for text, size, color, bold in lines:
            f = font(size, bold=bold) if not any(ord(c) > 127 for c in text) else cjk_font(size)
            w = line_width(text) if size == 19 else f.getlength(text)
            d.text(((W - (w if size == 19 else f.getlength(text))) / 2, y), text, font=f, fill=color)
            y += size + 22
        self.hold(img, seconds)

    def terminal_scene(self, command, output_lines, out_colors=None, cps=110,
                       line_delay=0.14, tail=0.8, caption=None):
        """先打字机显示命令，再逐行显示输出。"""
        img, d = base_frame()
        if caption:
            draw_mixed(d, 26, H - 46, caption, (120, 170, 190), ascii_font=font(16), cjk=cjk_font(16))
        prompt = "$ "
        x0, y0 = 26, 60
        d.text((x0, y0), prompt, font=ASCII_BOLD, fill=GREEN)
        x = x0 + ASCII_BOLD.getlength(prompt)
        step = max(1, int(cps / self.fps))
        n = len(command)
        i = 0
        while i <= n:
            img2 = img.copy()
            d2 = ImageDraw.Draw(img2)
            draw_mixed(d2, x, y0, command[:i], FG)
            self.frames.append(img2)
            i += step
        # 命令完整，停留
        self.hold(img, 0.35)
        # 输出逐行
        y = y0 + 40
        shown = []
        for idx, line in enumerate(output_lines):
            for wrapped in wrap(line):
                shown.append(wrapped)
                img2 = img.copy()
                d2 = ImageDraw.Draw(img2)
                draw_mixed(d2, x, y0, command, FG)
                yy = y
                for k, s in enumerate(shown):
                    color = FG
                    if out_colors and k < len(out_colors) and out_colors[k] == "gray":
                        color = GRAY
                    if s.startswith("ISSUE"):
                        color = RED
                    if "passed:" in s and "failed: 0" in s:
                        color = GREEN
                    if s.startswith("OK"):
                        color = GREEN
                    draw_mixed(d2, x0, yy, s, color)
                    yy += 26
                self.frames.append(img2)
                self.hold(img2, line_delay if idx < len(output_lines) - 1 else tail)

    def save(self, path, ffmpeg):
        cmd = [ffmpeg, "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
               "-s", f"{W}x{H}", "-r", str(self.fps), "-i", "-",
               "-an", "-vcodec", "libx264", "-pix_fmt", "yuv420p",
               "-crf", "23", "-movflags", "+faststart", path]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        for frame in self.frames:
            proc.stdin.write(frame.tobytes())
        proc.stdin.close()
        err = proc.stderr.read().decode("utf-8", "replace")
        code = proc.wait()
        if code != 0:
            raise RuntimeError(f"ffmpeg failed: {err[-800:]}")


def run(cmd):
    """执行命令并返回输出行。"""
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (proc.stdout + proc.stderr).replace("\r", "").replace("\t", "  ")
    lines = [ln.rstrip() for ln in out.split("\n")]
    while lines and lines[-1] == "":
        lines.pop()
    return lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ffmpeg", default=os.environ.get("FFMPEG", "ffmpeg"))
    ap.add_argument("--fps", type=int, default=24)
    ap.add_argument("--out", default=os.path.join("docs", "demo.mp4"))
    args = ap.parse_args()

    video = Video(args.fps)

    video.title_card([
        ("moonkml", 64, (255, 255, 255), True),
        ("Pure MoonBit KML / KMZ library", 26, CYAN, False),
        ("24 commits · 74 tests · wasm-gc / js / native", 19, GRAY, False),
    ], 3.0)

    scenes = [
        ("moon run cmd/main --target wasm-gc -- examples/oracle.kmz --summary",
         "① 读取真实 KMZ：simplekml 生成、DEFLATE 压缩"),
        ("moon run cmd/main --target wasm-gc -- examples/sample.gpx --summary",
         "② 导入 GPX 1.1：wpt / trk"),
        ("moon run cmd/main --target wasm-gc -- examples/oracle.kml --geojson",
         "③ 导出 GeoJSON（RFC 7946）"),
        ("moon run cmd/main --target wasm-gc -- examples/sample.kml --validate",
         "④ 文档校验：结构完整"),
    ]
    for cmd, caption in scenes:
        lines = run(cmd.split())
        video.terminal_scene(cmd, lines, caption=caption)

    # 校验失败示例
    broken = os.path.join("examples", "negative", "broken.kml")
    cmd = f"moon run cmd/main --target wasm-gc -- {broken} --validate"
    video.terminal_scene(cmd, run(cmd.split()), caption="⑤ 校验能发现坏数据：外环未闭合")

    cmd = "moon bench benchmarks --target wasm-gc --release"
    video.terminal_scene(cmd, run(cmd.split()), caption="⑥ 性能：解析 1000 个点约 5 ms")

    cmd = "moon test --target wasm-gc"
    video.terminal_scene(cmd, run(cmd.split()), caption="⑦ 74 个测试，三后端一致")

    video.title_card([
        ("Apache-2.0", 30, CYAN, False),
        ("github.com/cp15695540483/moonkml", 24, (255, 255, 255), False),
        ("mooncakes.io/docs/cp15695540483/moonkml", 24, (255, 255, 255), False),
    ], 3.0)

    out = os.path.join(ROOT, args.out) if not os.path.isabs(args.out) else args.out
    os.makedirs(os.path.dirname(out), exist_ok=True)
    video.save(out, args.ffmpeg)
    print(f"video written: {out}")
    print(f"frames: {len(video.frames)}  duration: {len(video.frames)/args.fps:.1f}s")


if __name__ == "__main__":
    main()
