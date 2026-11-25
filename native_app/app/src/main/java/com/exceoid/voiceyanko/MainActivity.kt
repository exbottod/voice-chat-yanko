package com.exceoid.voiceyanko

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

private val Bg = Color(0xFF12061F)
private val Card = Color(0xFF1E1030)
private val Pink = Color(0xFFFF4FA3)
private val Muted = Color(0xFFB9A9CC)

data class RoomRow(val id: String, val title: String, val topic: String, val listeners: Int)

/** Jumlah kursi mic per baris untuk mode 13 / 11 / 9. */
fun seatRows(mode: String): List<Int> = when (mode.trim().substringBefore(' ').toIntOrNull() ?: 13) {
    9 -> listOf(4, 4)
    11 -> listOf(5, 5)
    else -> listOf(4, 4, 4)
}

class MainActivity : ComponentActivity() {
    private val micPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        VoiceRoom.init(this)
        if (VoiceRoom.ready) micPermission.launch(Manifest.permission.RECORD_AUDIO)
        val auth = FirebaseAuth.getInstance()
        if (auth.currentUser == null) auth.signInAnonymously()
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(primary = Pink, background = Bg, surface = Card)) {
                Surface(modifier = Modifier.fillMaxSize(), color = Bg) { AppRoot() }
            }
        }
    }
}

@Composable
private fun AppRoot() {
    var openRoom by remember { mutableStateOf<RoomRow?>(null) }
    val room = openRoom
    if (room == null) PartyScreen(onOpen = { openRoom = it }) else RoomScreen(room, onBack = { openRoom = null })
}

@Composable
private fun PartyScreen(onOpen: (RoomRow) -> Unit) {
    var rooms by remember { mutableStateOf<List<RoomRow>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        FirebaseFirestore.getInstance().collection("rooms").limit(40).get()
            .addOnSuccessListener { snap ->
                rooms = snap.documents.map { d ->
                    RoomRow(
                        id = d.id,
                        title = d.getString("title") ?: "Room",
                        topic = d.getString("topic") ?: "",
                        listeners = (d.getLong("listeners") ?: 0L).toInt(),
                    )
                }
                loading = false
            }
            .addOnFailureListener { loading = false }
    }

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("Voice Yanko", color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        Text("Native Kotlin", color = Muted, fontSize = 12.sp)
        Spacer(Modifier.height(14.dp))
        if (loading) {
            Text("Memuat room...", color = Muted)
        } else if (rooms.isEmpty()) {
            Text("Belum ada room aktif", color = Muted)
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(rooms) { r ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(Card)
                            .clickable { onOpen(r) }
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(
                            Modifier.size(44.dp).clip(CircleShape).background(Pink.copy(alpha = 0.25f)),
                            contentAlignment = Alignment.Center,
                        ) { Text(r.title.take(1).uppercase(), color = Color.White) }
                        Spacer(Modifier.size(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(r.title, color = Color.White, fontWeight = FontWeight.SemiBold)
                            Text(r.topic.ifBlank { "Tanpa topik" }, color = Muted, fontSize = 12.sp)
                        }
                        Text("${r.listeners}", color = Pink, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun RoomScreen(room: RoomRow, onBack: () -> Unit) {
    var micMode by remember { mutableStateOf("13 Mics") }
    var seats by remember { mutableStateOf<Map<Int, String>>(emptyMap()) }
    var micOn by remember { mutableStateOf(true) }
    var roomSub by remember { mutableStateOf<ListenerRegistration?>(null) }
    var seatSub by remember { mutableStateOf<ListenerRegistration?>(null) }

    LaunchedEffect(room.id) {
        val db = FirebaseFirestore.getInstance()
        roomSub = db.collection("rooms").document(room.id).addSnapshotListener { snap, _ ->
            micMode = snap?.getString("micMode") ?: "13 Mics"
        }
        seatSub = db.collection("rooms").document(room.id).collection("seats")
            .addSnapshotListener { snap, _ ->
                val map = mutableMapOf<Int, String>()
                snap?.documents?.forEach { d ->
                    val n = d.id.toIntOrNull() ?: return@forEach
                    map[n] = d.getString("name") ?: d.getString("uid") ?: "User"
                }
                seats = map
            }
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: "guest"
        if (VoiceRoom.ready) VoiceRoom.join(room.id, uid)
    }

    DisposableEffect(room.id) {
        onDispose {
            roomSub?.remove()
            seatSub?.remove()
            VoiceRoom.leave()
        }
    }

    Column(Modifier.fillMaxSize().padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Keluar", color = Muted, fontSize = 13.sp, modifier = Modifier.clickable { onBack() })
            Spacer(Modifier.size(12.dp))
            Column(Modifier.weight(1f)) {
                Text(room.title, color = Color.White, fontWeight = FontWeight.Bold)
                Text(micMode, color = Muted, fontSize = 11.sp)
            }
            Text(if (VoiceRoom.ready) "Agora aktif" else "Agora belum aktif", color = Pink, fontSize = 11.sp)
        }
        Spacer(Modifier.height(16.dp))
        seatRows(micMode).forEach { count ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                for (i in 0 until count) {
                    SeatCell(label = seats[(i + 1)] ?: "")
                }
            }
        }
        Spacer(Modifier.weight(1f))
        Row(
            Modifier.fillMaxWidth().padding(8.dp),
            horizontalArrangement = Arrangement.Center,
        ) {
            Box(
                Modifier
                    .size(54.dp)
                    .clip(CircleShape)
                    .background(if (micOn) Pink else Color(0xFF2C1B42))
                    .clickable {
                        micOn = !micOn
                        VoiceRoom.setMic(micOn)
                    },
                contentAlignment = Alignment.Center,
            ) { Text(if (micOn) "Mic" else "Mute", color = Color.White, fontSize = 12.sp) }
        }
    }
}

@Composable
private fun SeatCell(label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(4.dp)) {
        Box(
            Modifier
                .size(54.dp)
                .clip(CircleShape)
                .background(Card)
                .border(1.dp, Color.White.copy(alpha = 0.12f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                if (label.isBlank()) "+" else label.take(1).uppercase(),
                color = if (label.isBlank()) Muted else Color.White,
                fontSize = 16.sp,
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            if (label.isBlank()) "kosong" else label.take(8),
            color = Muted,
            fontSize = 9.sp,
        )
    }
}
