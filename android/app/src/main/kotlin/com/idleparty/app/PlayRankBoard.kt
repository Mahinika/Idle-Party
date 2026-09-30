package com.idleparty.app

import android.app.Activity
import com.google.android.gms.games.LeaderboardsClient
import com.google.android.gms.games.PageDirection
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.leaderboard.LeaderboardScoreBuffer
import com.google.android.gms.games.leaderboard.LeaderboardVariant
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/// Public Play scores for one board. Play returns at most 25 per call, so this
/// keeps asking for the next page until the board ends.
object PlayRankBoard {
    private const val pageSize = 25
    private const val maxRows = 2000

    fun loadAll(activity: Activity, leaderboardId: String, result: MethodChannel.Result) {
        if (leaderboardId.isEmpty()) {
            result.error("rank_board", "missing board", null)
            return
        }
        val client = PlayGames.getLeaderboardsClient(activity)
        val rows = ArrayList<Map<String, Any?>>()
        val replied = AtomicBoolean(false)

        fun ok() {
            if (replied.compareAndSet(false, true)) result.success(rows)
        }

        fun fail(message: String?) {
            if (replied.compareAndSet(false, true)) {
                result.error("rank_board", message ?: "load failed", null)
            }
        }

        fun consume(buffer: LeaderboardScoreBuffer) {
            val count = buffer.count
            for (i in 0 until count) {
                if (rows.size >= maxRows) break
                val item = buffer.get(i) ?: continue
                val holder = item.scoreHolder
                rows.add(
                    mapOf(
                        "rank" to item.rank,
                        "name" to item.scoreHolderDisplayName,
                        "rawScore" to item.rawScore,
                        "playerId" to holder?.playerId,
                        "scoreTag" to item.scoreTag,
                    ),
                )
            }
            val more = count >= pageSize && rows.size < maxRows
            if (!more) {
                buffer.release()
                ok()
                return
            }
            // loadMoreScores releases [buffer].
            client
                .loadMoreScores(buffer, pageSize, PageDirection.NEXT)
                .addOnSuccessListener { annotated ->
                    val next = annotated.get()?.scores
                    if (next == null) {
                        ok()
                    } else {
                        consume(next)
                    }
                }
                .addOnFailureListener {
                    if (rows.isNotEmpty()) ok() else fail(it.localizedMessage)
                }
        }

        client
            .loadTopScores(
                leaderboardId,
                LeaderboardVariant.TIME_SPAN_ALL_TIME,
                LeaderboardVariant.COLLECTION_PUBLIC,
                pageSize,
                true,
            )
            .addOnSuccessListener { annotated: com.google.android.gms.games.AnnotatedData<LeaderboardsClient.LeaderboardScores> ->
                val buffer = annotated.get()?.scores
                if (buffer == null) {
                    fail("empty")
                } else {
                    consume(buffer)
                }
            }
            .addOnFailureListener { fail(it.localizedMessage) }
    }
}
