package com.idleparty.app

import android.app.Activity
import com.google.android.gms.games.PlayGames
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/// Snapshot names plus Play's stale bit.
///
/// games_services 5.3.0 returns the buffer from `annotatedData.get()` and
/// drops `isStale()`. A stale empty list is not proof the snapshot is missing.
object PlaySnapshotList {
    fun list(activity: Activity, result: MethodChannel.Result) {
        val replied = AtomicBoolean(false)
        fun ok(payload: Map<String, Any?>) {
            if (replied.compareAndSet(false, true)) result.success(payload)
        }
        fun fail(message: String?) {
            if (replied.compareAndSet(false, true)) {
                result.error("snapshots", message ?: "list failed", null)
            }
        }
        val client = PlayGames.getSnapshotsClient(activity)
        client
            .load(true)
            .addOnSuccessListener { annotated ->
                val buffer = annotated.get()
                if (buffer == null) {
                    ok(mapOf("names" to emptyList<String>(), "stale" to true))
                    return@addOnSuccessListener
                }
                val names = ArrayList<String>(buffer.count)
                for (i in 0 until buffer.count) {
                    val item = buffer.get(i) ?: continue
                    names.add(item.uniqueName)
                }
                buffer.release()
                ok(mapOf("names" to names, "stale" to annotated.isStale))
            }
            .addOnFailureListener { fail(it.localizedMessage) }
    }
}
