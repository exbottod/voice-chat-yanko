#!/usr/bin/env python3
"""Pembuat unduhan kecil (file selisih) untuk update di dalam APK.

Membandingkan APK rilis sebelumnya dengan APK yang baru dibangun, lalu menulis
berkas .bsdiff + patch-info.json ke folder web/ supaya ikut ter-deploy ke
Firebase Hosting. Dialog pembaruan di aplikasi membaca patch-info.json,
mengunduh berkas selisih (biasanya < 1 MB), menggabungkannya dengan APK yang
terpasang, lalu membuka pemasang Android.

Jalankan dari root repo setelah APK release selesai dibangun:
  python3 tool/buat_patch.py
"""
import hashlib
import json
import os
import pathlib
import sys
import urllib.request

try:
    import bsdiff4
except ImportError:
    sys.exit("Pasang dulu: pip install bsdiff4")

REPO = os.environ.get("GITHUB_REPOSITORY", "exbottod/voice-chat-yanko")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
RUN = os.environ.get("RUN_NUMBER", "")
APK_BARU = "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
MAKS_LAMA = 3


def api(path):
    req = urllib.request.Request(
        "https://api.github.com" + path,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Accept": "application/vnd.github+json",
        },
    )
    return json.load(urllib.request.urlopen(req, timeout=60))


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for blok in iter(lambda: f.read(1 << 20), b""):
            h.update(blok)
    return h.hexdigest()


def unduh(url, tujuan):
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + TOKEN,
            "Accept": "application/octet-stream",
        },
    )
    with urllib.request.urlopen(req, timeout=180) as res, open(tujuan, "wb") as f:
        for blok in iter(lambda: res.read(1 << 20), b""):
            f.write(blok)
    return os.path.getsize(tujuan)


def main():
    if not os.path.isfile(APK_BARU):
        sys.exit("APK baru tidak ada: " + APK_BARU)
    if not RUN:
        sys.exit("RUN_NUMBER kosong")

    versi_baru = "1.0." + RUN
    web = pathlib.Path("web")
    (web / "patch").mkdir(parents=True, exist_ok=True)

    # Rilis sebelumnya dipakai sebagai versi dasar patch.
    try:
        rilis = api("/repos/%s/releases?per_page=10" % REPO)
    except Exception as e:
        print("gagal membaca daftar rilis:", e)
        rilis = []

    lama = []
    for r in rilis:
        tag = (r.get("tag_name") or "").strip()
        if not tag.startswith("v1.0."):
            continue
        versi = tag[1:]
        if versi == versi_baru:
            continue
        aset = None
        for a in r.get("assets") or []:
            if a.get("name") == "app-arm64-v8a-release.apk":
                aset = a
                break
        if aset is None:
            continue
        lama.append((versi, aset.get("browser_download_url") or aset.get("url")))
        if len(lama) >= MAKS_LAMA:
            break

    entri = []
    for versi_lama, url in lama:
        tmp = "/tmp/apk-lama-%s.apk" % versi_lama.replace(".", "_")
        try:
            ukuran = unduh(url, tmp)
        except Exception as e:
            print("lewati %s: gagal unduh (%s)" % (versi_lama, e))
            continue
        if ukuran <= 0:
            continue
        nama = "patch-%s-%s-arm64.bsdiff" % (versi_lama, versi_baru)
        tujuan = web / "patch" / nama
        try:
            bsdiff4.file_diff(tmp, APK_BARU, str(tujuan))
            uji = "/tmp/uji-%s.apk" % versi_lama.replace(".", "_")
            bsdiff4.file_patch(tmp, uji, str(tujuan))
            if sha256(uji) != sha256(APK_BARU):
                print("patch %s gagal uji, dilewati" % versi_lama)
                tujuan.unlink(missing_ok=True)
                continue
            os.unlink(uji)
        except Exception as e:
            print("patch %s gagal dibuat: %s" % (versi_lama, e))
            continue
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        entri.append(
            {
                "dari": versi_lama,
                "ke": versi_baru,
                "arm64": {
                    "file": nama,
                    "ukuran": tujuan.stat().st_size,
                    "sha256": sha256(str(tujuan)),
                },
            }
        )
        print(
            "patch %s -> %s : %.2f MB"
            % (versi_lama, versi_baru, tujuan.stat().st_size / 1048576)
        )

    # Patch versi lama yang masih berguna dipertahankan (maks 8 pasangan).
    lama_json = web / "patch-info.json"
    semua = []
    if lama_json.exists():
        try:
            semua = json.loads(lama_json.read_text()).get("patch", [])
        except Exception:
            semua = []
    kunci = {(e.get("dari"), e.get("ke")) for e in entri}
    for e in semua:
        if (e.get("dari"), e.get("ke")) not in kunci:
            berkas = web / "patch" / (e.get("arm64", {}).get("file") or "")
            if berkas.exists():
                entri.append(e)
    entri = entri[:8]
    lama_json.write_text(json.dumps({"patch": entri}, indent=1))
    print("patch-info.json: %d pasangan" % len(entri))


if __name__ == "__main__":
    main()
