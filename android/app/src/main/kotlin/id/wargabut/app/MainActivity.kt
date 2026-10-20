package com.wargabut.app

import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "id.wargabut/wearable_sync"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncProfile" -> {
                    val username = call.argument<String>("username") ?: ""
                    val displayName = call.argument<String>("displayName") ?: ""
                    val role = call.argument<String>("role") ?: ""
                    val bio = call.argument<String>("bio") ?: ""
                    val instagram = call.argument<String>("instagram") ?: ""

                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            // 1. Kirim via DataItem (persisted sync)
                            val putDataReq = PutDataMapRequest.create("/wargabut/profile").apply {
                                dataMap.putString("username", username)
                                dataMap.putString("displayName", displayName)
                                dataMap.putString("role", role)
                                dataMap.putString("bio", bio)
                                dataMap.putString("instagram", instagram)
                                dataMap.putLong("timestamp", System.currentTimeMillis())
                            }.asPutDataRequest().setUrgent()

                            Wearable.getDataClient(this@MainActivity).putDataItem(putDataReq).await()

                            // 2. Kirim pesan langsung ke connected Wear OS nodes (instant push)
                            val nodes = Wearable.getNodeClient(this@MainActivity).connectedNodes.await()
                            val jsonPayload = JSONObject().apply {
                                put("username", username)
                                put("displayName", displayName)
                                put("role", role)
                                put("bio", bio)
                                put("instagram", instagram)
                            }.toString().toByteArray(Charsets.UTF_8)

                            for (node in nodes) {
                                Wearable.getMessageClient(this@MainActivity)
                                    .sendMessage(node.id, "/wargabut/sync", jsonPayload)
                                    .await()
                            }

                            runOnUiThread {
                                result.success(mapOf("status" to "ok", "nodesCount" to nodes.size))
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("SYNC_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "checkWearConnected" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val nodes = Wearable.getNodeClient(this@MainActivity).connectedNodes.await()
                            val nodeNames = nodes.map { it.displayName }
                            runOnUiThread {
                                result.success(mapOf("connected" to nodes.isNotEmpty(), "devices" to nodeNames))
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.success(mapOf("connected" to false, "devices" to emptyList<String>()))
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
