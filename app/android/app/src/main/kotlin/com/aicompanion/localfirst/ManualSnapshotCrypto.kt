package com.aicompanion.localfirst

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.GeneralSecurityException
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.CipherInputStream
import javax.crypto.CipherOutputStream
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Password-encrypted manual transfer envelope.
 *
 * The Nearby path already uses an encrypted authenticated transport. Manual
 * fallback may travel through arbitrary file apps, so the same plaintext ZIP
 * is wrapped in AES-256-GCM with a PBKDF2-HMAC-SHA256 key. No password/key is
 * persisted by AI Companion.
 */
object ManualSnapshotCrypto {
    private val MAGIC = byteArrayOf(
        'A'.code.toByte(), 'I'.code.toByte(), 'C'.code.toByte(), 'M'.code.toByte(),
        '2'.code.toByte(), '6'.code.toByte(), 1, 0,
    )
    private const val ITERATIONS = 210_000
    private const val SALT_BYTES = 16
    private const val IV_BYTES = 12
    private const val KEY_BITS = 256
    private const val BUFFER_SIZE = 64 * 1024

    fun encrypt(input: InputStream, output: OutputStream, passphrase: CharArray) {
        requirePassphrase(passphrase)
        val salt = ByteArray(SALT_BYTES).also { SecureRandom().nextBytes(it) }
        val iv = ByteArray(IV_BYTES).also { SecureRandom().nextBytes(it) }
        val header = buildHeader(salt, iv, ITERATIONS)
        val key = deriveKey(passphrase, salt, ITERATIONS)
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, iv))
            cipher.updateAAD(header)
            DataOutputStream(output).use { raw ->
                raw.write(header)
                CipherOutputStream(raw, cipher).use { encrypted ->
                    input.use { source -> source.copyTo(encrypted, BUFFER_SIZE) }
                }
            }
        } finally {
            key.encoded?.fill(0)
            passphrase.fill('\u0000')
        }
    }

    fun decrypt(input: InputStream, output: OutputStream, passphrase: CharArray) {
        requirePassphrase(passphrase)
        try {
            val data = DataInputStream(input)
            val fixedHeaderSize = MAGIC.size + 4 + SALT_BYTES + IV_BYTES
            val header = ByteArray(fixedHeaderSize)
            data.readFully(header)
            if (!header.copyOfRange(0, MAGIC.size).contentEquals(MAGIC)) {
                throw GeneralSecurityException("manual_snapshot_bad_magic")
            }
            val iterationOffset = MAGIC.size
            val iterations = ByteBuffer.wrap(header, iterationOffset, 4)
                .order(ByteOrder.BIG_ENDIAN)
                .int
            if (iterations !in 100_000..1_000_000) {
                throw GeneralSecurityException("manual_snapshot_bad_kdf")
            }
            val saltOffset = MAGIC.size + 4
            val ivOffset = saltOffset + SALT_BYTES
            val salt = header.copyOfRange(saltOffset, saltOffset + SALT_BYTES)
            val iv = header.copyOfRange(ivOffset, ivOffset + IV_BYTES)
            val key = deriveKey(passphrase, salt, iterations)
            try {
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
                cipher.updateAAD(header)
                CipherInputStream(data, cipher).use { decrypted ->
                    output.use { target -> decrypted.copyTo(target, BUFFER_SIZE) }
                }
            } finally {
                key.encoded?.fill(0)
            }
        } finally {
            passphrase.fill('\u0000')
        }
    }

    private fun buildHeader(salt: ByteArray, iv: ByteArray, iterations: Int): ByteArray {
        val buffer = ByteBuffer.allocate(MAGIC.size + 4 + SALT_BYTES + IV_BYTES)
            .order(ByteOrder.BIG_ENDIAN)
        buffer.put(MAGIC)
        buffer.putInt(iterations)
        buffer.put(salt)
        buffer.put(iv)
        return buffer.array()
    }

    private fun deriveKey(passphrase: CharArray, salt: ByteArray, iterations: Int): SecretKeySpec {
        val spec = PBEKeySpec(passphrase, salt, iterations, KEY_BITS)
        return try {
            val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
            try {
                SecretKeySpec(bytes, "AES")
            } finally {
                bytes.fill(0)
            }
        } finally {
            spec.clearPassword()
        }
    }

    private fun requirePassphrase(passphrase: CharArray) {
        require(passphrase.size in 8..128) { "manual transfer passphrase must be 8..128 characters" }
    }
}
