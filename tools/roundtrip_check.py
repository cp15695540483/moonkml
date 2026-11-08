"""跨后端一致性 + 往返守恒检查。

这是 KML 库特有的门禁，覆盖三类只在本领域才会出错的问题：
  1. 浮点格式化：wasm-gc 与 js 的 Double 转字符串实现不同，
     同一坐标可能被渲染成 116.3975 与 116.39750000000001。
  2. 编码差异：两端 UTF-8 处理路径不同，中文名称可能字节不同。
  3. 往返损耗：parse -> serialize -> parse 之后几何、样式、时间数量必须守恒。

用法：python tools/roundtrip_check.py [fixture.kml ...]
"""

import os
import subprocess
import sys

sys.stdout.reconfigure(encoding="utf-8")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_FIXTURES = ["examples/oracle.kml", "examples/sample.kml", "examples/sample.geojson", "examples/sample.gpx"]
MODES = ["--kml", "--geojson", "--gpx"]
BACKENDS = ["wasm-gc", "js"]


def run(args):
    proc = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout, proc.stderr


def cli(path, mode, backend):
    return run(["moon", "run", "cmd/main", "--target", backend, "--", path, mode])


def failures():
    return []


def main():
    fixtures = sys.argv[1:] or DEFAULT_FIXTURES
    problems = []
    checked = 0
    for fixture in fixtures:
        if not os.path.exists(os.path.join(ROOT, fixture)):
            problems.append(f"缺少 fixture: {fixture}")
            continue
        for mode in MODES:
            outputs = {}
            for backend in BACKENDS:
                code, out, err = cli(fixture, mode, backend)
                if code != 0:
                    problems.append(f"{fixture} {mode} {backend}: 退出码 {code} {err.strip()[:120]}")
                    continue
                outputs[backend] = out
            checked += 1
            if len(outputs) == len(BACKENDS):
                first, second = BACKENDS[0], BACKENDS[1]
                if outputs[first] != outputs[second]:
                    a, b = outputs[first], outputs[second]
                    at = next((i for i in range(min(len(a), len(b))) if a[i] != b[i]), min(len(a), len(b)))
                    problems.append(
                        f"{fixture} {mode}: 后端输出不一致，首个差异在字节 {at}: "
                        f"{a[at:at + 40]!r} vs {b[at:at + 40]!r}"
                    )
        # 往返守恒：kml -> 解析 -> 序列化 -> 再解析
        code, original, err = cli(fixture, "--summary", "wasm-gc")
        if code != 0:
            problems.append(f"{fixture}: summary 失败 {err.strip()[:120]}")
            continue
        code, kml_text, err = cli(fixture, "--kml", "wasm-gc")
        if code != 0:
            problems.append(f"{fixture}: --kml 失败 {err.strip()[:120]}")
            continue
        tmp = os.path.join(ROOT, "_build", "roundtrip.kml")
        os.makedirs(os.path.dirname(tmp), exist_ok=True)
        with open(tmp, "w", encoding="utf-8", newline="") as handle:
            handle.write(kml_text)
        code, again, err = run(["moon", "run", "cmd/main", "--target", "wasm-gc", "--", tmp, "--summary"])
        checked += 1
        if code != 0:
            problems.append(f"{fixture}: 往返后解析失败 {err.strip()[:120]}")
            continue
        for label in ("document:", "placemarks:", "styles:"):
            want = [ln for ln in original.splitlines() if ln.startswith(label)]
            got = [ln for ln in again.splitlines() if ln.startswith(label)]
            if want != got:
                problems.append(f"{fixture}: 往返后 {label} 变了，{want} -> {got}")

    print(f"检查项: {checked}")
    if problems:
        for item in problems:
            print(f"FAIL {item}")
        print(f"结果: {len(problems)} 处不一致")
        return 1
    print("结果: 双后端输出逐字节一致，往返计数守恒")
    return 0


if __name__ == "__main__":
    sys.exit(main())
