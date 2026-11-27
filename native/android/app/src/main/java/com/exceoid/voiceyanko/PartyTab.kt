package com.exceoid.voiceyanko

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.auravox.app.R
import com.google.firebase.firestore.FirebaseFirestore

internal fun PartyTab(onOpenRoom: (RoomRow) -> Unit) {
    val ctx = LocalContext.current
    // Cache dulu: daftar langsung tampil walau jaringan belum menjawab.
    val cache = remember { RoomCache.get(ctx) }
    var rooms by remember { mutableStateOf(cache) }
    var loading by remember { mutableStateOf(cache.isEmpty()) }
    var errorMsg by remember { mutableStateOf<String?>(null) }

    // Satu kali ambil data, bukan addSnapshotListener: daftar room tidak perlu
    // dipantau terus karena setiap perubahan kecil akan mengunduh ulang.
    LaunchedEffect(Unit) {
        FirebaseFirestore.getInstance()
            .collection("rooms")
            .limit(20)
            .get()
            .addOnSuccessListener { snap ->
                val hasil = snap.documents.mapNotNull { d ->
                    // Room terkunci (isOpen = false) tidak ditampilkan.
                    if (d.getBoolean("isOpen") == false) return@mapNotNull null
                    RoomRow(
                        id = d.id,
                        title = d.getString("title") ?: "Room",
                        topic = d.getString("topic") ?: "",
                        listeners = (d.getLong("listeners") ?: 0L).toInt(),
                    )
                }.sortedByDescending { it.listeners }
                rooms = hasil
                RoomCache.save(ctx, hasil)
                errorMsg = null
                loading = false
            }
            .addOnFailureListener { e ->
                // Kesalahan ditampilkan, tidak dibuang diam-diam.
                errorMsg = e.message ?: e.javaClass.simpleName
                loading = false
            }
    }

    Column(Modifier.fillMaxSize()) {
        Row(
            Modifier.fillMaxWidth().padding(start = 18.dp, end = 18.dp, top = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Voice Yanko", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.weight(1f))
            Box(
                Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(Surface2),
                contentAlignment = Alignment.Center,
            ) { Text("+", color = Pink, fontSize = 18.sp, fontWeight = FontWeight.Bold) }
        }

        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .height(104.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Brush.horizontalGradient(listOf(Violet, Pink))),
        ) {
            Aset(R.drawable.demo_room_bg_1, Modifier.fillMaxSize(), 0.55f)
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Brush.horizontalGradient(listOf(BgTop.copy(alpha = 0.75f), Color.Transparent))),
            )
            Column(Modifier.padding(16.dp)) {
                Text("Party malam ini", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text("Masuk room, naik mic, ngobrol bareng", color = Color.White.copy(alpha = 0.9f), fontSize = 11.sp)
            }
            Box(
                Modifier
                    .align(Alignment.BottomEnd)
                    .padding(14.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Color.White.copy(alpha = 0.22f))
                    .padding(horizontal = 10.dp, vertical = 5.dp),
            ) { Text("Populer", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold) }
        }

        Text(
            "Room aktif",
            color = Color.White,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(start = 18.dp, top = 4.dp, bottom = 8.dp),
        )

        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                loading -> Column(
                    Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    repeat(3) {
                        Box(
                            Modifier.fillMaxWidth().height(72.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(Surface2)
                        )
                    }
                }
                rooms.isEmpty() -> Column(Modifier.padding(18.dp)) {
                    Text(
                        text = if (errorMsg != null) "Gagal memuat: $errorMsg" else "Belum ada room",
                        color = Color.White,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = if (errorMsg != null) "Periksa aturan Firestore dan internet" else "Jadilah yang pertama membuat room",
                        color = Muted,
                        fontSize = 11.sp,
                    )
                }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 16.dp, end = 16.dp, bottom = 12.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(rooms, key = { it.id }) { r -> RoomCard(r) { onOpenRoom(r) } }
                }
            }
        }
    }
}
