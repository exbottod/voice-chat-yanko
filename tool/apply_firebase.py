#!/usr/bin/env python3
"""Tempelkan konfigurasi Firebase ke folder android/ yang digenerate flutter create."""
import os
import re
import sys

APP_ID = "com.exceoid.voiceyanko"
MIN_SDK = 23
GS_PLUGIN_VERSION = "4.4.2"

ROOT = "android"
SETTINGS = [
    os.path.join(ROOT, "settings.gradle.kts"),
    os.path.join(ROOT, "settings.gradle"),
]
APP_GRADLE = [
    os.path.join(ROOT, "app", "build.gradle.kts"),
    os.path.join(ROOT, "app", "build.gradle"),
]


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


def patch_settings(text):
    if "com.google.gms.google-services" in text:
        return text
    match = re.search(r"plugins\s*\{", text)
    if not match:
        return text
    line = '\n    id("com.google.gms.google-services") version "%s" apply false' % GS_PLUGIN_VERSION
    return text[: match.end()] + line + text[match.end():]


def add_lint_skip(text, is_kts):
    if "lint {" in text or "lint{" in text:
        return text
    match = re.search(r"\n\s*buildTypes\s*\{", text)
    if not match:
        return text
    if is_kts:
        block = (
            "\n    lint {\n"
            "        checkReleaseBuilds = false\n"
            "        abortOnError = false\n"
            "    }\n"
        )
    else:
        block = (
            "\n    lint {\n"
            "        checkReleaseBuilds false\n"
            "        abortOnError false\n"
            "    }\n"
        )
    return text[: match.start() + 1] + block + text[match.start() + 1:]


def keep_all_resources(text, is_kts):
    """Cegah resource shrinker membuang gambar res yang tidak direferensikan kode."""
    if "isShrinkResources" in text or "shrinkResources false" in text:
        return text
    match = re.search(r"\n\s*release\s*\{", text)
    if not match:
        return text
    if is_kts:
        block = (
            "\n            isMinifyEnabled = false"
            "\n            isShrinkResources = false"
        )
    else:
        block = (
            "\n            minifyEnabled false"
            "\n            shrinkResources false"
        )
    return text[: match.end()] + block + text[match.end():]


def patch_app_gradle(text, is_kts=True):
    if 'id("com.google.gms.google-services")' not in text:
        match = re.search(r"plugins\s*\{", text)
        if match:
            text = text[: match.end()] + '\n    id("com.google.gms.google-services")' + text[match.end():]
    text = re.sub(r'applicationId\s*=\s*"[^"]*"', 'applicationId = "%s"' % APP_ID, text)
    text = re.sub(r'applicationId\s+"[^"]*"', 'applicationId "%s"' % APP_ID, text)
    text = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = %d" % MIN_SDK, text)
    text = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion %d" % MIN_SDK, text)
    text = re.sub(r"minSdk\s*=\s*\d+", "minSdk = %d" % MIN_SDK, text)
    text = re.sub(r"minSdkVersion\s+\d+", "minSdkVersion %d" % MIN_SDK, text)
    text = add_lint_skip(text, is_kts)
    text = keep_all_resources(text, is_kts)
    return text


def main():
    if not os.path.isdir(ROOT):
        sys.exit("folder android/ tidak ada - jalankan flutter create dulu")

    gs_target = os.path.join(ROOT, "app", "google-services.json")
    if os.path.exists("native/android/google-services.json"):
        with open("native/android/google-services.json", "rb") as src:
            data = src.read()
        with open(gs_target, "wb") as dst:
            dst.write(data)
        print("copied google-services.json ->", gs_target)
    else:
        sys.exit("native/android/google-services.json tidak ditemukan")

    changed = 0
    for path in SETTINGS:
        if os.path.exists(path):
            before = read(path)
            after = patch_settings(before)
            if after != before:
                write(path, after)
                changed += 1
            print("settings:", path, "patched" if after != before else "unchanged")

    for path in APP_GRADLE:
        if os.path.exists(path):
            before = read(path)
            after = patch_app_gradle(before, path.endswith(".kts"))
            if after != before:
                write(path, after)
                changed += 1
            print("app gradle:", path, "patched" if after != before else "unchanged")

    print("selesai, file diubah:", changed)


if __name__ == "__main__":
    main()
