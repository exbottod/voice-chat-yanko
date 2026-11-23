#!/usr/bin/env python3
"""Aktifkan signing release memakai keystore dari GitHub Secrets (env var)."""
import os
import re
import sys

APP_GRADLE = [
    os.path.join("android", "app", "build.gradle.kts"),
    os.path.join("android", "app", "build.gradle"),
]

SIGNING_KTS = """    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "upload-keystore.p12")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
            storeType = "pkcs12"
        }
    }

"""

SIGNING_GROOVY = """    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH") ?: "upload-keystore.p12")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
            storeType "pkcs12"
        }
    }

"""


def patch(text, is_kts):
    if 'create("release")' in text or re.search(r"signingConfigs\s*\{\s*release", text):
        return text
    match = re.search(r"\n\s*buildTypes\s*\{", text)
    if not match:
        return text
    block = SIGNING_KTS if is_kts else SIGNING_GROOVY
    text = text[: match.start() + 1] + block + text[match.start() + 1:]
    text = text.replace('signingConfig = signingConfigs.getByName("debug")',
                        'signingConfig = signingConfigs.getByName("release")')
    text = text.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
    return text


def main():
    changed = 0
    for path in APP_GRADLE:
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            before = fh.read()
        after = patch(before, path.endswith(".kts"))
        if after != before:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(after)
            changed += 1
            print("signing patched:", path)
        else:
            print("signing unchanged:", path)
    if changed == 0:
        sys.exit("gagal menambahkan signingConfigs release")
    print("signing siap")


if __name__ == "__main__":
    main()
