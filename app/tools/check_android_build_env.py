#!/usr/bin/env python3
from __future__ import annotations
import os, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def found(name: str) -> str:
    return shutil.which(name) or ''

checks = {
    'flutter': found('flutter'),
    'dart': found('dart'),
    'java': found('java'),
    'adb': found('adb'),
    'sdkmanager': found('sdkmanager'),
}
wrapper = ROOT / 'android' / 'gradlew'
wrapper_jar = ROOT / 'android' / 'gradle' / 'wrapper' / 'gradle-wrapper.jar'
print('AI Companion Android build environment')
for key, value in checks.items():
    print(f'{key:12}: {value or "MISSING"}')
print(f'ANDROID_HOME : {os.environ.get("ANDROID_HOME") or "MISSING"}')
print(f'gradlew      : {wrapper if wrapper.exists() else "MISSING"}')
print(f'wrapper jar  : {wrapper_jar if wrapper_jar.exists() else "MISSING"}')
ready = bool(checks['flutter'] and checks['dart'] and checks['java'] and checks['adb'])
print(f'build-ready  : {"yes" if ready else "no"}')
raise SystemExit(0 if ready else 2)
