package com.aicompanion.localfirst

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.AdvertisingOptions
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import com.google.android.gms.nearby.connection.DiscoveryOptions
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.Strategy
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap
import org.json.JSONObject

/**
 * Process-wide Nearby transport.
 *
 * v0.26 binds takeover control messages to the exact snapshot session that was
 * transferred. A stale constant ACK/request is never enough to switch Active
 * Brain ownership.
 */
class NearbyTransferManager private constructor(private val context: Context) {
    private data class SnapshotSession(
        val snapshotId: String,
        val lineageId: String,
        val sourceDeviceId: String,
        val sourceGeneration: Long,
        val stateSha256: String,
    ) {
        fun valid(): Boolean =
            snapshotId.isNotBlank() && lineageId.isNotBlank() && sourceDeviceId.isNotBlank() &&
                sourceGeneration > 0L && stateSha256.matches(Regex("^[0-9a-f]{64}$"))
    }

    private data class PendingTakeover(
        val session: SnapshotSession,
        val targetDeviceId: String,
        val targetActivationGeneration: Long,
    )

    private val client: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val main = Handler(Looper.getMainLooper())
    private val listeners = ConcurrentHashMap<String, (Map<String, Any?>) -> Unit>()
    private val endpointNames = ConcurrentHashMap<String, String>()
    private val incomingFiles = ConcurrentHashMap<Long, Payload>()
    private val outgoingIds = ConcurrentHashMap.newKeySet<Long>()
    private val outgoingSessions = ConcurrentHashMap<String, SnapshotSession>()
    private val pendingTakeovers = ConcurrentHashMap<String, PendingTakeover>()

    fun addListener(ownerId: String, listener: (Map<String, Any?>) -> Unit) {
        listeners[ownerId] = listener
    }

    fun removeListener(ownerId: String) {
        listeners.remove(ownerId)
    }

    fun startAdvertising() {
        stopTransportOnly()
        val options = AdvertisingOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        client.startAdvertising(deviceName(), SERVICE_ID, connectionCallback, options)
            .addOnSuccessListener { emit("advertisingStarted") }
            .addOnFailureListener { e ->
                emit("nearbyError", mapOf("operation" to "advertise", "message" to (e.message ?: e.javaClass.simpleName)))
            }
    }

    fun startDiscovery() {
        stopTransportOnly()
        val options = DiscoveryOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build()
        client.startDiscovery(SERVICE_ID, discoveryCallback, options)
            .addOnSuccessListener { emit("discoveryStarted") }
            .addOnFailureListener { e ->
                emit("nearbyError", mapOf("operation" to "discover", "message" to (e.message ?: e.javaClass.simpleName)))
            }
    }

    fun requestConnection(endpointId: String) {
        if (endpointId.isBlank()) {
            emit("connectionFailed", mapOf("endpointId" to endpointId, "status" to "empty_endpoint"))
            return
        }
        client.requestConnection(deviceName(), endpointId, connectionCallback)
            .addOnFailureListener { e ->
                emit("connectionFailed", mapOf("endpointId" to endpointId, "status" to (e.message ?: e.javaClass.simpleName)))
            }
    }

    fun acceptConnection(endpointId: String) {
        client.acceptConnection(endpointId, payloadCallback)
            .addOnFailureListener { e ->
                emit("connectionFailed", mapOf("endpointId" to endpointId, "status" to (e.message ?: e.javaClass.simpleName)))
            }
    }

    fun rejectConnection(endpointId: String) {
        client.rejectConnection(endpointId)
    }

    fun confirmTakeover(
        endpointId: String,
        snapshotId: String,
        lineageId: String,
        sourceDeviceId: String,
        sourceGeneration: Long,
        stateSha256: String,
        targetDeviceId: String,
        targetActivationGeneration: Long,
    ) {
        val session = SnapshotSession(
            snapshotId,
            lineageId,
            sourceDeviceId,
            sourceGeneration,
            stateSha256,
        )
        if (!session.valid() || targetDeviceId.isBlank() || targetActivationGeneration != sourceGeneration + 1L) {
            emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "invalid_request_metadata"))
            return
        }
        val pending = PendingTakeover(session, targetDeviceId, targetActivationGeneration)
        pendingTakeovers[endpointId] = pending
        val payload = Payload.fromBytes(controlJson("takeover_request", pending).toByteArray(StandardCharsets.UTF_8))
        client.sendPayload(endpointId, payload).addOnFailureListener { e ->
            pendingTakeovers.remove(endpointId, pending)
            emit(
                "takeoverAckFailed",
                mapOf(
                    "phase" to "request_send",
                    "endpointId" to endpointId,
                    "status" to (e.message ?: e.javaClass.simpleName),
                    "snapshotId" to snapshotId,
                ),
            )
        }
    }

    fun sendFile(
        endpointId: String,
        path: String,
        snapshotId: String,
        lineageId: String,
        sourceDeviceId: String,
        sourceGeneration: Long,
        stateSha256: String,
    ) {
        val file = File(path)
        if (!file.exists() || !file.isFile) {
            emit("transferFailed", mapOf("status" to "file_not_found"))
            return
        }
        val session = SnapshotSession(snapshotId, lineageId, sourceDeviceId, sourceGeneration, stateSha256)
        if (!session.valid()) {
            emit("transferFailed", mapOf("status" to "invalid_snapshot_metadata"))
            return
        }
        runCatching {
            val payload = Payload.fromFile(file).apply {
                setFileName(file.name)
                setSensitive(true)
            }
            outgoingSessions[endpointId] = session
            outgoingIds.add(payload.id)
            RuntimeDiagnosticStore.record(
                context, "nearby", "send_started", "info", "send_started",
                metadata = mapOf(
                    "endpointId" to endpointId,
                    "snapshotId" to snapshotId,
                    "sourceGeneration" to sourceGeneration,
                    "payloadBytes" to file.length(),
                    "direction" to "outbound",
                ),
            )
            client.sendPayload(endpointId, payload)
                .addOnFailureListener { e ->
                    outgoingIds.remove(payload.id)
                    outgoingSessions.remove(endpointId, session)
                    emit("transferFailed", mapOf("status" to (e.message ?: e.javaClass.simpleName)))
                }
        }.onFailure { e ->
            outgoingSessions.remove(endpointId, session)
            emit("transferFailed", mapOf("status" to (e.message ?: e.javaClass.simpleName)))
        }
    }

    fun stopAll() {
        runCatching { client.stopAdvertising() }
        runCatching { client.stopDiscovery() }
        runCatching { client.stopAllEndpoints() }
        endpointNames.clear()
        incomingFiles.clear()
        outgoingIds.clear()
        outgoingSessions.clear()
        pendingTakeovers.clear()
        emit("stopped")
    }

    private fun stopTransportOnly() {
        runCatching { client.stopAdvertising() }
        runCatching { client.stopDiscovery() }
    }

    private val discoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
            endpointNames[endpointId] = info.endpointName
            emit("endpointFound", mapOf("endpointId" to endpointId, "endpointName" to info.endpointName))
        }

        override fun onEndpointLost(endpointId: String) {
            endpointNames.remove(endpointId)
            emit("endpointLost", mapOf("endpointId" to endpointId))
        }
    }

    private val connectionCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(endpointId: String, info: ConnectionInfo) {
            endpointNames[endpointId] = info.endpointName
            emit(
                "connectionInitiated",
                mapOf(
                    "endpointId" to endpointId,
                    "endpointName" to info.endpointName,
                    "verificationCode" to info.authenticationDigits,
                ),
            )
        }

        override fun onConnectionResult(endpointId: String, resolution: ConnectionResolution) {
            val status = resolution.status.statusCode
            if (status == CommonStatusCodes.SUCCESS) {
                stopTransportOnly()
                emit(
                    "connected",
                    mapOf(
                        "endpointId" to endpointId,
                        "endpointName" to (endpointNames[endpointId] ?: endpointId),
                    ),
                )
            } else {
                emit("connectionFailed", mapOf("endpointId" to endpointId, "status" to status))
            }
        }

        override fun onDisconnected(endpointId: String) {
            outgoingSessions.remove(endpointId)
            pendingTakeovers.remove(endpointId)
            emit("disconnected", mapOf("endpointId" to endpointId))
        }
    }

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(endpointId: String, payload: Payload) {
            when (payload.type) {
                Payload.Type.FILE -> incomingFiles[payload.id] = payload
                Payload.Type.BYTES -> handleControlPayload(endpointId, payload.asBytes() ?: byteArrayOf())
            }
        }

        override fun onPayloadTransferUpdate(endpointId: String, update: PayloadTransferUpdate) {
            if (incomingFiles.containsKey(update.payloadId) && update.totalBytes > MAX_NEARBY_PAYLOAD_BYTES) {
                incomingFiles.remove(update.payloadId)
                runCatching { client.cancelPayload(update.payloadId) }
                emit(
                    "transferFailed",
                    mapOf(
                        "status" to "payload_too_large",
                        "payloadId" to update.payloadId,
                        "totalBytes" to update.totalBytes,
                    ),
                )
                return
            }
            when (update.status) {
                PayloadTransferUpdate.Status.SUCCESS -> {
                    if (outgoingIds.remove(update.payloadId)) {
                        val session = outgoingSessions[endpointId]
                        emit(
                            "sendComplete",
                            mapOf(
                                "endpointId" to endpointId,
                                "payloadId" to update.payloadId,
                                "snapshotId" to session?.snapshotId,
                                "totalBytes" to update.totalBytes,
                            ),
                        )
                        return
                    }
                    val payload = incomingFiles.remove(update.payloadId) ?: return
                    copyIncomingFile(endpointId, payload, update.payloadId)
                }
                PayloadTransferUpdate.Status.FAILURE,
                PayloadTransferUpdate.Status.CANCELED -> {
                    outgoingIds.remove(update.payloadId)
                    outgoingSessions.remove(endpointId)
                    incomingFiles.remove(update.payloadId)
                    emit("transferFailed", mapOf("status" to update.status, "payloadId" to update.payloadId))
                }
                else -> Unit
            }
        }
    }

    private fun handleControlPayload(endpointId: String, bytes: ByteArray) {
        if (bytes.isEmpty() || bytes.size > MAX_CONTROL_BYTES) {
            emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "invalid_control_size"))
            return
        }
        val json = runCatching {
            JSONObject(String(bytes, StandardCharsets.UTF_8))
        }.getOrElse {
            emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "legacy_or_invalid_control"))
            return
        }
        if (json.optString("protocol") != CONTROL_PROTOCOL) {
            emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "protocol_mismatch"))
            return
        }
        when (json.optString("type")) {
            "takeover_request" -> handleTakeoverRequest(endpointId, json)
            "takeover_ack" -> handleTakeoverAck(endpointId, json)
            "takeover_reject" -> {
                pendingTakeovers.remove(endpointId)
                emit(
                    "takeoverRejected",
                    mapOf(
                        "endpointId" to endpointId,
                        "reason" to json.optString("reason", "remote_rejected"),
                        "snapshotId" to json.optString("snapshot_id"),
                    ),
                )
            }
            else -> emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "unknown_control_type"))
        }
    }

    private fun handleTakeoverRequest(endpointId: String, json: JSONObject) {
        val requested = parsePending(json) ?: run {
            sendReject(endpointId, json.optString("snapshot_id"), "invalid_request_metadata")
            return
        }
        val outgoing = outgoingSessions[endpointId]
        if (outgoing == null || !sameSession(outgoing, requested.session)) {
            sendReject(endpointId, requested.session.snapshotId, "snapshot_session_mismatch")
            return
        }
        if (requested.targetActivationGeneration != outgoing.sourceGeneration + 1L) {
            sendReject(endpointId, outgoing.snapshotId, "activation_generation_mismatch")
            return
        }

        val fenced = NativeEventStore.fenceForTakeover(
            context,
            outgoing.snapshotId,
            outgoing.lineageId,
            outgoing.sourceGeneration,
            requested.targetDeviceId,
        )
        if (!fenced) {
            sendReject(endpointId, outgoing.snapshotId, "source_state_no_longer_matches")
            return
        }

        // Fence SQLite first, then disable persistent overlay restoration. If
        // ACK delivery later fails, the source intentionally stays offline so
        // two brains can never become active from an ambiguous network result.
        OverlayBubbleService.stopForStandby(context)
        outgoingSessions.remove(endpointId, outgoing)
        emit(
            "remoteTookOver",
            sessionMap(outgoing) + mapOf(
                "endpointId" to endpointId,
                "targetDeviceId" to requested.targetDeviceId,
                "targetActivationGeneration" to requested.targetActivationGeneration,
            ),
        )

        val ack = Payload.fromBytes(controlJson("takeover_ack", requested).toByteArray(StandardCharsets.UTF_8))
        client.sendPayload(endpointId, ack).addOnFailureListener { e ->
            emit(
                "takeoverAckFailed",
                sessionMap(outgoing) + mapOf(
                    "phase" to "ack_send",
                    "endpointId" to endpointId,
                    "status" to (e.message ?: e.javaClass.simpleName),
                ),
            )
        }
    }

    private fun handleTakeoverAck(endpointId: String, json: JSONObject) {
        val ack = parsePending(json) ?: run {
            emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to "invalid_ack_metadata"))
            return
        }
        val pending = pendingTakeovers[endpointId]
        if (pending == null || !samePending(pending, ack)) {
            emit(
                "takeoverRejected",
                mapOf(
                    "endpointId" to endpointId,
                    "reason" to "stale_or_mismatched_ack",
                    "snapshotId" to ack.session.snapshotId,
                ),
            )
            return
        }
        pendingTakeovers.remove(endpointId, pending)
        emit(
            "takeoverConfirmed",
            sessionMap(ack.session) + mapOf(
                "endpointId" to endpointId,
                "targetDeviceId" to ack.targetDeviceId,
                "targetActivationGeneration" to ack.targetActivationGeneration,
            ),
        )
    }

    private fun sendReject(endpointId: String, snapshotId: String, reason: String) {
        emit("takeoverRejected", mapOf("endpointId" to endpointId, "reason" to reason, "snapshotId" to snapshotId))
        val json = JSONObject()
            .put("protocol", CONTROL_PROTOCOL)
            .put("type", "takeover_reject")
            .put("snapshot_id", snapshotId)
            .put("reason", reason)
            .toString()
        runCatching { client.sendPayload(endpointId, Payload.fromBytes(json.toByteArray(StandardCharsets.UTF_8))) }
    }

    private fun controlJson(type: String, pending: PendingTakeover): String = JSONObject()
        .put("protocol", CONTROL_PROTOCOL)
        .put("type", type)
        .put("snapshot_id", pending.session.snapshotId)
        .put("lineage_id", pending.session.lineageId)
        .put("source_device_id", pending.session.sourceDeviceId)
        .put("source_generation", pending.session.sourceGeneration)
        .put("state_sha256", pending.session.stateSha256)
        .put("target_device_id", pending.targetDeviceId)
        .put("target_activation_generation", pending.targetActivationGeneration)
        .toString()

    private fun parsePending(json: JSONObject): PendingTakeover? {
        val session = SnapshotSession(
            snapshotId = json.optString("snapshot_id"),
            lineageId = json.optString("lineage_id"),
            sourceDeviceId = json.optString("source_device_id"),
            sourceGeneration = json.optLong("source_generation", 0L),
            stateSha256 = json.optString("state_sha256"),
        )
        val targetDeviceId = json.optString("target_device_id")
        val activation = json.optLong("target_activation_generation", 0L)
        if (!session.valid() || targetDeviceId.isBlank() || activation <= 0L) return null
        return PendingTakeover(session, targetDeviceId, activation)
    }

    private fun sameSession(left: SnapshotSession, right: SnapshotSession): Boolean =
        left.snapshotId == right.snapshotId && left.lineageId == right.lineageId &&
            left.sourceDeviceId == right.sourceDeviceId && left.sourceGeneration == right.sourceGeneration &&
            left.stateSha256 == right.stateSha256

    private fun samePending(left: PendingTakeover, right: PendingTakeover): Boolean =
        sameSession(left.session, right.session) && left.targetDeviceId == right.targetDeviceId &&
            left.targetActivationGeneration == right.targetActivationGeneration

    private fun sessionMap(session: SnapshotSession): Map<String, Any?> = mapOf(
        "snapshotId" to session.snapshotId,
        "lineageId" to session.lineageId,
        "sourceDeviceId" to session.sourceDeviceId,
        "sourceGeneration" to session.sourceGeneration,
        "stateSha256" to session.stateSha256,
    )

    private fun copyIncomingFile(endpointId: String, payload: Payload, payloadId: Long) {
        Thread {
            runCatching {
                val destination = File(context.cacheDir, "ai_companion_received_${System.currentTimeMillis()}.zip")
                val filePayload = requireNotNull(payload.asFile())
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val uri = requireNotNull(filePayload.asUri())
                    context.contentResolver.openInputStream(uri).use { input ->
                        requireNotNull(input)
                        FileOutputStream(destination).use { output -> input.copyTo(output) }
                    }
                    runCatching { context.contentResolver.delete(uri, null, null) }
                } else {
                    @Suppress("DEPRECATION")
                    val source = requireNotNull(filePayload.asJavaFile())
                    source.inputStream().use { input ->
                        FileOutputStream(destination).use { output -> input.copyTo(output) }
                    }
                    runCatching { source.delete() }
                }
                emit(
                    "fileReceived",
                    mapOf(
                        "filePath" to destination.absolutePath,
                        "payloadId" to payloadId,
                        "endpointId" to endpointId,
                        "payloadBytes" to destination.length(),
                    ),
                )
            }.onFailure { e ->
                emit("transferFailed", mapOf("status" to (e.message ?: e.javaClass.simpleName), "payloadId" to payloadId))
            }
        }.start()
    }

    private fun deviceName(): String = "${Build.MANUFACTURER} ${Build.MODEL}".trim().take(48)

    private fun emit(type: String, extra: Map<String, Any?> = emptyMap()) {
        // Persist only a bounded redacted phase trail. The user-facing event
        // still carries the live endpoint/session data needed by TransferPage,
        // but that plaintext never enters RuntimeDiagnosticStore.
        RuntimeDiagnosticStore.recordNearby(context, type, extra)
        val message = HashMap<String, Any?>()
        message["type"] = type
        message.putAll(extra)
        main.post {
            listeners.values.toList().forEach { listener ->
                runCatching { listener(message) }
            }
        }
    }

    companion object {
        private const val SERVICE_ID = "com.aicompanion.localfirst.transfer"
        private const val MAX_NEARBY_PAYLOAD_BYTES = 512L * 1024L * 1024L
        private const val MAX_CONTROL_BYTES = 16 * 1024
        private const val CONTROL_PROTOCOL = "ai_companion_takeover_v3"
        @Volatile private var instance: NearbyTransferManager? = null

        fun get(context: Context): NearbyTransferManager =
            instance ?: synchronized(this) {
                instance ?: NearbyTransferManager(context.applicationContext).also { instance = it }
            }
    }
}
