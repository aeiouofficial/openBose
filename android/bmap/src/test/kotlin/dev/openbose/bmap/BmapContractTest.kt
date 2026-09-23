package dev.openbose.bmap

import kotlinx.serialization.json.*
import kotlin.test.*

class BmapContractTest {
    private fun fixture(name: String): JsonObject {
        val text = requireNotNull(javaClass.classLoader.getResource("$name.json")) {
            "Fixture not on test classpath: $name"
        }.readText()
        return Json.parseToJsonElement(text).jsonObject
    }

    private fun bytes(hex: String): ByteArray =
        hex.filterNot(Char::isWhitespace).chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    @Test fun readOnlyCommandsMatchSharedSpecification() {
        val rows = fixture("read-only-commands")["commands"]!!.jsonArray
        rows.forEach { row ->
            val obj = row.jsonObject
            val name = obj["name"]!!.jsonPrimitive.content
            val wire = bytes(obj["requestHex"]!!.jsonPrimitive.content)
            assertContentEquals(wire, ReadOnlyCommands.buildGet(name))
            ReadOnlyCommands.requireAllowed(wire)
            val packet = BmapPacket.parseExact(wire)
            assertEquals(obj["block"]!!.jsonPrimitive.int, packet.block)
            assertEquals(obj["function"]!!.jsonPrimitive.int, packet.function)
            assertEquals(BmapPacket.GET, packet.operator)
            assertTrue(packet.payload.isEmpty())
        }
        assertFailsWith<IllegalStateException> { ReadOnlyCommands.buildGet("ota") }
    }

    @Test fun blockedWritesAndPayloadGetRequests() {
        fixture("synthetic-fixtures")["blockedOutbound"]!!.jsonArray.forEach {
            assertFailsWith<SecurityException> {
                ReadOnlyCommands.requireAllowed(bytes(it.jsonPrimitive.content))
            }
        }
        assertFailsWith<IllegalArgumentException> {
            ReadOnlyCommands.requireAllowed(byteArrayOf(2, 2, 1))
        }
    }

    @Test fun sharedFullFrameVectors() {
        fixture("synthetic-fixtures")["fullFrames"]!!.jsonArray.forEach {
            val obj = it.jsonObject
            val wire = bytes(obj["hex"]!!.jsonPrimitive.content)
            val parsed = BmapPacket.parseExact(wire)
            assertEquals(obj["block"]!!.jsonPrimitive.int, parsed.block)
            assertEquals(obj["function"]!!.jsonPrimitive.int, parsed.function)
            assertEquals(obj["operator"]!!.jsonPrimitive.int, parsed.operator)
            assertContentEquals(bytes(obj["payloadHex"]!!.jsonPrimitive.content), parsed.payload)
            assertContentEquals(wire, parsed.toWire())
        }
    }

    @Test fun malformedSingleFramesAreRejected() {
        fixture("synthetic-fixtures")["invalidSingleFrames"]!!.jsonArray.forEach {
            assertFailsWith<IllegalArgumentException> {
                BmapPacket.parseExact(bytes(it.jsonObject["hex"]!!.jsonPrimitive.content))
            }
        }
    }

    @Test fun fragmentationAndCoalescing() {
        val obj = fixture("synthetic-fixtures")["fragmented"]!!.jsonObject
        val decoder = BmapStreamDecoder()
        val result = obj["chunksHex"]!!.jsonArray.flatMap {
            decoder.feed(bytes(it.jsonPrimitive.content))
        }.map { it.toWire().toList() }
        val expected = obj["expectedFramesHex"]!!.jsonArray
            .map { bytes(it.jsonPrimitive.content).toList() }
        assertEquals(expected, result)
        assertEquals(0, decoder.pendingBytes)
    }

    @Test fun bufferOverflowAndReset() {
        val decoder = BmapStreamDecoder()
        decoder.feed(byteArrayOf(2, 2))
        assertEquals(2, decoder.pendingBytes)
        assertFailsWith<IllegalArgumentException> {
            decoder.feed(ByteArray(BmapStreamDecoder.MAX_BUFFER))
        }
        assertEquals(0, decoder.pendingBytes)
        decoder.feed(byteArrayOf(2))
        decoder.reset()
        assertEquals(0, decoder.pendingBytes)
    }

    @Test fun packetsOwnTheirPayload() {
        val data = byteArrayOf(0x50)
        val packet = BmapPacket(2, 2, 3, data)
        data[0] = 0
        assertEquals(0x50, packet.payload[0].toInt() and 0xff)
        assertFailsWith<IllegalArgumentException> { BmapPacket(2, 2, 3, ByteArray(256)) }
    }
}
