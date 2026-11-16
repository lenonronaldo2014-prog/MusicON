package com.musicon.musicon

import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.InputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Test

class LimitedInputTest {
    @Test fun readsEmptyAndExactLimit() {
        assertArrayEquals(byteArrayOf(), ByteArrayInputStream(byteArrayOf()).readLimited(0))
        val bytes = ByteArray(16384) { (it % 251).toByte() }
        assertArrayEquals(bytes, ByteArrayInputStream(bytes).readLimited(bytes.size))
    }

    @Test(expected = IOException::class) fun rejectsOversizedBody() {
        ByteArrayInputStream(ByteArray(8193)).readLimited(8192)
    }

    @Test fun supportsPartialReads() {
        val input = object : InputStream() {
            var next = 0
            override fun read(): Int = if (next < 57) next++ else -1
        }
        assertArrayEquals(ByteArray(57) { it.toByte() }, input.readLimited(57))
    }

    @Test(expected = IOException::class) fun preservesNetworkFailure() {
        val input = object : InputStream() {
            override fun read(): Int = throw IOException("test failure")
        }
        input.readLimited(64)
    }
}
