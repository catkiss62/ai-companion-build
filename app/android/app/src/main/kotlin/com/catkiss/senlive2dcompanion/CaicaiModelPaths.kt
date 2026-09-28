package com.catkiss.senlive2dcompanion

import java.io.File
import java.io.IOException

/** The lab's canonical-root contract, also used after staging is promoted. */
internal object CaicaiModelPaths {
    fun child(root: File, path: String): File? = runCatching {
        if (path.isBlank() || File(path).isAbsolute) return null
        val base = root.canonicalFile
        File(base, path).canonicalFile.takeIf { it.path.startsWith(base.path + File.separator) }
    }.getOrNull()

    fun relative(root: File, file: File): String {
        val base = root.canonicalFile
        val target = file.canonicalFile
        if (!target.path.startsWith(base.path + File.separator)) throw IOException("模型路径不安全")
        return target.relativeTo(base).invariantSeparatorsPath
    }
}
