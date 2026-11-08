#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
d2.py — Diagnóstico preciso de mojibake.
Distingue entre tildes españolas legítimas y basura real.

Uso:
    python d2.py archivo.java
    python d2.py . --ext .dart .java
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

# Caracteres válidos en español y símbolos comunes (NO son mojibake)
ESPERADOS = set(
    'áéíóúÁÉÍÓÚñÑüÜ'
    '¿¡°·€'
    '–—“”‘’…'   # guiones largos y comillas tipográficas
    '→←↑↓'      # flechas
    '✓✔✗✘'     # checks
    '²³'        # superíndices
)

# Firmas inequívocas de mojibake (doble codificación UTF-8→Latin1)
FIRMAS_MOJIBAKE = [
    'ðŸ', 'â€', 'â€“', 'â€”', 'â€œ', 'â€\x9d',
    'Ã¡', 'Ã©', 'Ã­', 'Ã³', 'Ãº', 'Ã±', 'Ã\x81',
    'в–', 'в”', 'в•', 'вҖ', 'в‹', 'в€™',
    'â‚', 'âƒ', 'â†', 'âˆ',
]


def esc(s: str) -> str:
    out = []
    for c in s:
        o = ord(c)
        if 32 <= o < 127 and c != '\\':
            out.append(c)
        else:
            out.append(f'\\u{o:04x}')
    return ''.join(out)


def diagnosticar(path: Path) -> None:
    raw = path.read_bytes()
    texto = raw.decode('utf-8', errors='replace')

    print(f"\n{'═' * 70}")
    print(f"📄 {path.name}")
    print(f"   {path}")
    print(f"{'═' * 70}")

    # 1) Contar TODOS los caracteres no-ASCII
    no_ascii = Counter(c for c in texto if ord(c) >= 0x80)

    # 2) Separar: válidos vs sospechosos
    validos = {c: n for c, n in no_ascii.items() if c in ESPERADOS}
    raros = {c: n for c, n in no_ascii.items() if c not in ESPERADOS}

    # ─── VÁLIDOS ─────────────────────────────────────────────────────────
    if validos:
        print(f"\n  ✅ Caracteres válidos en español ({sum(validos.values())}):")
        for c, n in sorted(validos.items(), key=lambda x: -x[1]):
            print(f"       '{esc(c)}'  ({n}x)  U+{ord(c):04X}")

    # ─── RAROS ───────────────────────────────────────────────────────────
    if not raros:
        print(f"\n  ✅ No hay caracteres sospechosos. FALSO POSITIVO.")
        return

    print(f"\n  ⚠️  Caracteres SOSPECHOSOS ({sum(raros.values())}):")
    for c, n in sorted(raros.items(), key=lambda x: -x[1]):
        print(f"       '{esc(c)}'  ({n}x)  U+{ord(c):04X}")

    # ─── FIRMAS DE MOJIBAKE REAL ─────────────────────────────────────────
    firmas_encontradas = []
    for firma in FIRMAS_MOJIBAKE:
        n = texto.count(firma)
        if n > 0:
            firmas_encontradas.append((firma, n))

    if firmas_encontradas:
        print(f"\n  ❌ Firmas de MOJIBAKE detectadas:")
        for firma, n in firmas_encontradas:
            print(f"       '{esc(firma)}'  ({n}x)")

        print(f"\n  📋 Contextos (máx. 10):")
        for firma, _ in firmas_encontradas:
            idx = 0
            count = 0
            while count < 10:
                pos = texto.find(firma, idx)
                if pos < 0:
                    break
                line = texto[:pos].count('\n') + 1
                col = pos - texto.rfind('\n', 0, pos)
                ini = max(0, pos - 25)
                fin = min(len(texto), pos + len(firma) + 25)
                ctx = esc(texto[ini:fin]).replace('\n', '⏎')
                print(f"       L{line}:{col}  …{ctx}…")
                idx = pos + 1
                count += 1
    else:
        print(f"\n  ℹ️  Sin firmas de mojibake. Los caracteres raros podrían ser")
        print(f"      legítimos pero no están en la lista ESPERADOS.")
        print(f"      Revisa el contexto manualmente.")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('path', nargs='?', default='.')
    ap.add_argument('--ext', nargs='+', default=['.dart', '.java'])
    args = ap.parse_args()

    root = Path(args.path).resolve()
    files = [root] if root.is_file() else sorted(set(
        f for ext in args.ext for f in root.rglob(f'*{ext}')
    ))

    for f in files:
        diagnosticar(f)

    print(f"\n{'═' * 70}")
    print(f"  Revisados: {len(files)} archivo(s)")
    print(f"{'═' * 70}")

    return 0


if __name__ == '__main__':
    sys.exit(main())