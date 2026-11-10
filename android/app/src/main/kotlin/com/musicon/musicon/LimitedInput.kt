// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.musicon

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream

/** Bounded metadata read using APIs available on every supported Android. */
internal fun InputStream.readLimited(limit: Int): ByteArray {
    require(limit >= 0)
    val output = ByteArrayOutputStream(minOf(limit, 8192))
    val buffer = ByteArray(8192)
    while (true) {
        val count = read(buffer)
        if (count == -1) break
        if (count == 0) {
            val single = read()
            if (single == -1) break
            if (output.size() == limit) throw IOException("Response too large")
            output.write(single)
            continue
        }
        if (count > limit - output.size()) throw IOException("Response too large")
        output.write(buffer, 0, count)
    }
    return output.toByteArray()
}
