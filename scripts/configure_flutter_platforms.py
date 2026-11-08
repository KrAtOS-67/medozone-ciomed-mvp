#!/usr/bin/env python3
"""Aplica ajustes mínimos de red local a los wrappers generados por Flutter.
Los permisos de HTTP sin TLS se habilitan solo en Android debug.
"""
from pathlib import Path
import plistlib
import sys
import xml.etree.ElementTree as ET

if len(sys.argv) != 2:
    raise SystemExit("Uso: configure_flutter_platforms.py RUTA_MOBILE")
root = Path(sys.argv[1]).resolve()

android = root / "android/app/src/main/AndroidManifest.xml"
if android.exists():
    android_ns = "http://schemas.android.com/apk/res/android"
    ET.register_namespace("android", android_ns)
    ns = "{" + android_ns + "}"
    tree = ET.parse(android)
    manifest = tree.getroot()
    internet_exists = any(
        element.tag == "uses-permission"
        and element.attrib.get(ns + "name") == "android.permission.INTERNET"
        for element in manifest
    )
    if not internet_exists:
        manifest.insert(0, ET.Element("uses-permission", {ns + "name": "android.permission.INTERNET"}))

    # No se permite HTTP sin cifrar en el manifiesto principal (incluye builds release).
    application = manifest.find("application")
    if application is not None:
        application.attrib.pop(ns + "usesCleartextTraffic", None)
    tree.write(android, encoding="utf-8", xml_declaration=True)

    # Override solo para la variante debug. La variante release conserva el default seguro.
    debug_manifest = root / "android/app/src/debug/AndroidManifest.xml"
    debug_manifest.parent.mkdir(parents=True, exist_ok=True)
    debug_manifest.write_text(
        f'''<manifest xmlns:android="{android_ns}">\n'''
        '''    <application android:usesCleartextTraffic="true" />\n'''
        '''</manifest>\n''',
        encoding="utf-8",
    )

info = root / "ios/Runner/Info.plist"
if info.exists():
    with info.open("rb") as stream:
        data = plistlib.load(stream)
    transport = data.setdefault("NSAppTransportSecurity", {})
    transport["NSAllowsLocalNetworking"] = True
    data.setdefault(
        "NSLocalNetworkUsageDescription",
        "Conexión al servidor MedOzone durante pruebas en red local.",
    )
    with info.open("wb") as stream:
        plistlib.dump(data, stream)

web = root / "web/index.html"
if web.exists():
    content = web.read_text(encoding="utf-8")
    content = content.replace("<title>medozone_ciomed</title>", "<title>MedOzone CIOMED</title>")
    web.write_text(content, encoding="utf-8")

print("Wrappers configurados. Android permite HTTP solo en debug; builds release deben usar HTTPS.")
