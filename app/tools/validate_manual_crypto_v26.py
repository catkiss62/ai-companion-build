#!/usr/bin/env python3
import pathlib, subprocess, tempfile, textwrap
ROOT=pathlib.Path(__file__).resolve().parents[1]
SRC=ROOT/'android/app/src/main/kotlin/com/aicompanion/localfirst/ManualSnapshotCrypto.kt'

def main():
    with tempfile.TemporaryDirectory(prefix='manual_crypto_v26_') as td:
        td=pathlib.Path(td)
        harness=td/'Harness.kt'
        harness.write_text(textwrap.dedent(r'''
            import com.aicompanion.localfirst.ManualSnapshotCrypto
            import java.io.ByteArrayInputStream
            import java.io.ByteArrayOutputStream

            fun main() {
                val original = ("relationship-state-" + "x".repeat(120000)).toByteArray()
                val encrypted = ByteArrayOutputStream()
                ManualSnapshotCrypto.encrypt(
                    ByteArrayInputStream(original), encrypted, "correct horse battery".toCharArray()
                )
                check(!encrypted.toByteArray().contentEquals(original))

                val decrypted = ByteArrayOutputStream()
                ManualSnapshotCrypto.decrypt(
                    ByteArrayInputStream(encrypted.toByteArray()), decrypted,
                    "correct horse battery".toCharArray()
                )
                check(decrypted.toByteArray().contentEquals(original))

                var wrongFailed = false
                try {
                    ManualSnapshotCrypto.decrypt(
                        ByteArrayInputStream(encrypted.toByteArray()), ByteArrayOutputStream(),
                        "definitely wrong pass".toCharArray()
                    )
                } catch (_: Throwable) { wrongFailed = true }
                check(wrongFailed)

                val truncated = encrypted.toByteArray().copyOf(encrypted.size() - 9)
                var truncatedFailed = false
                try {
                    ManualSnapshotCrypto.decrypt(
                        ByteArrayInputStream(truncated), ByteArrayOutputStream(),
                        "correct horse battery".toCharArray()
                    )
                } catch (_: Throwable) { truncatedFailed = true }
                check(truncatedFailed)
                println("[OK] AES-256-GCM manual snapshot roundtrip / wrong-pass / truncation")
            }
        '''))
        jar=td/'test.jar'
        subprocess.run(['kotlinc', str(SRC), str(harness), '-include-runtime', '-d', str(jar)], check=True)
        subprocess.run(['java','-jar',str(jar)],check=True)

if __name__=='__main__': main()
