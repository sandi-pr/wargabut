package id.wargabut.wear.datalayer

import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import id.wargabut.wear.data.UserManager
import org.json.JSONObject

class DataLayerListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "WargabutWearListener"
        private const val PATH_PROFILE = "/wargabut/profile"
        private const val PATH_SYNC_MESSAGE = "/wargabut/sync"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val uri = event.dataItem.uri
                if (uri.path == PATH_PROFILE) {
                    try {
                        val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                        val username = dataMap.getString("username", "sandy")
                        val displayName = dataMap.getString("displayName", "Sandy")
                        val role = dataMap.getString("role", "Cosplayer / Wargabut Member")
                        val bio = dataMap.getString("bio", "")
                        val instagram = dataMap.getString("instagram", "")

                        UserManager.getInstance(this).saveProfile(
                            username = username,
                            displayName = displayName,
                            role = role,
                            bio = bio,
                            instagram = instagram
                        )
                        Log.d(TAG, "Profile updated from phone: @$username ($displayName)")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error parsing profile DataItem", e)
                    }
                }
            }
        }
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == PATH_SYNC_MESSAGE) {
            try {
                val jsonStr = String(messageEvent.data, Charsets.UTF_8)
                val json = JSONObject(jsonStr)
                val username = json.optString("username", "sandy")
                val displayName = json.optString("displayName", username)
                val role = json.optString("role", "Wargabut Member")
                val bio = json.optString("bio", "")
                val instagram = json.optString("instagram", "")

                UserManager.getInstance(this).saveProfile(
                    username = username,
                    displayName = displayName,
                    role = role,
                    bio = bio,
                    instagram = instagram
                )
                Log.d(TAG, "Profile received via message: @$username")
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing sync message", e)
            }
        }
    }
}
