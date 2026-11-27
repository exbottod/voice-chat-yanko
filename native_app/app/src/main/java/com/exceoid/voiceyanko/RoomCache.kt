package com.exceoid.voiceyanko

import com.auravox.app.R

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Simpanan daftar room di HP.
 *
 * Tujuan: saat aplikasi dibuka, daftar room langsung tampil dari cache (tanpa
 * menunggu jaringan), lalu diperbarui diam-diam setelah data baru datang.
 * Memakai org.json bawaan Android supaya tidak perlu menambah pustaka Gson.
 */
object RoomCache {
    private const val PREFS = "auravox"
    private const val KEY = "cached_rooms_v1"

    fun get(ctx: Context): List<RoomRow> {
        return try {
            val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null) ?: return emptyList()
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                RoomRow(
                    id = o.optString("id"),
                    title = o.optString("title"),
                    topic = o.optString("topic"),
                    listeners = o.optInt("listeners"),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun save(ctx: Context, rooms: List<RoomRow>) {
        try {
            val arr = JSONArray()
            rooms.forEach { r ->
                arr.put(
                    JSONObject()
                        .put("id", r.id)
                        .put("title", r.title)
                        .put("topic", r.topic)
                        .put("listeners", r.listeners)
                )
            }
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, arr.toString()).apply()
        } catch (e: Exception) {
            // Gagal menyimpan cache tidak boleh menghentikan aplikasi.
        }
    }
}
