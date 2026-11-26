package com.exceoid.voiceyanko

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.TextButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query

private val Bg = Color(0xFF12061F)
private val Card = Color(0xFF1E1030)
private val Pink = Color(0xFFFF4FA3)
private val Muted = Color(0xFFB9A9CC)

data class RoomRow(val id: String, val title: String, val topic: String, val listeners: Int)

data class Seat(val seat: Int, val uid: String, val name: String)

data class ChatMsg(val id: String, val name: String, val text: String, val mine: Boolean)

/** Jumlah kursi mic per baris untuk mode 13 / 11 / 9. */
fun seatRows(mode: String): List<Int> = when (mode.trim().substringBefore(' ').toIntOrNull() ?: 13) {
    9 -> listOf(4, 4)
    11 -> listOf(5, 5)
    else -> listOf(4, 4, 4)
}

private fun myName(): String {
    val u = FirebaseAuth.getInstance().currentUser
    val n = u?.displayName
    if (!n.isNullOrBlank()) return n
    return "User " + (u?.uid?.take(4) ?: "0000")
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
                items(rooms, key = { it.id }) { r ->
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
                        Spacer(Modifier.width(12.dp))
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
    val db = remember { FirebaseFirestore.getInstance() }
    val myUid = remember { FirebaseAuth.getInstance().currentUser?.uid ?: "" }
    val nama = remember { myName() }

    var micMode by remember { mutableStateOf("13 Mics") }
    var seats by remember { mutableStateOf<Map<Int, Seat>>(emptyMap()) }
    var pesan by remember { mutableStateOf<List<ChatMsg>>(emptyList()) }
    var mySeat by remember { mutableStateOf<Int?>(null) }
    var micOn by remember { mutableStateOf(true) }
    var ownerId by remember { mutableStateOf("") }
    var locked by remember { mutableStateOf<Set<Int>>(emptySet()) }
    var sheetSeat by remember { mutableStateOf<Seat?>(null) }
    var showMode by remember { mutableStateOf(false) }
    val akuOwner = myUid.isNotEmpty() && myUid == ownerId
    var draft by remember { mutableStateOf("") }
    var subs by remember { mutableStateOf<List<ListenerRegistration>>(emptyList()) }

    LaunchedEffect(room.id) {
        val roomRef = db.collection("rooms").document(room.id)
        val list = mutableListOf<ListenerRegistration>()

        list += roomRef.addSnapshotListener { snap, _ ->
            micMode = snap?.getString("micMode") ?: "13 Mics"
            ownerId = snap?.getString("ownerId") ?: ""
            locked = (snap?.get("lockedSeats") as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() }?.toSet() ?: emptySet()
        }
        list += roomRef.collection("seats").addSnapshotListener { snap, _ ->
            val map = mutableMapOf<Int, Seat>()
            snap?.documents?.forEach { d ->
                val n = (d.getLong("seat") ?: d.id.toLongOrNull() ?: -1L).toInt()
                val uid = d.getString("uid") ?: ""
                if (n >= 0 && uid.isNotEmpty()) {
                    map[n] = Seat(n, uid, d.getString("name") ?: "User")
                }
            }
            seats = map
        }
        list += roomRef.collection("messages")
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snap, _ ->
                pesan = snap?.documents?.mapNotNull { d ->
                    val text = d.getString("text") ?: return@mapNotNull null
                    ChatMsg(
                        id = d.id,
                        name = d.getString("name") ?: "User",
                        text = text,
                        mine = d.getString("uid") == myUid,
                    )
                } ?: emptyList()
            }

        subs = list
        if (VoiceRoom.ready) VoiceRoom.join(room.id, myUid)
    }

    DisposableEffect(room.id) {
        onDispose {
            subs.forEach { it.remove() }
            VoiceRoom.leave()
            // Turun dari kursi saat keluar room.
            mySeat?.let { s ->
                db.collection("rooms").document(room.id).collection("seats").document("$s").delete()
            }
        }
    }

    fun duduk(seat: Int) {
        val ref = db.collection("rooms").document(room.id).collection("seats")
        val isi = seats[seat]
        if (isi != null && isi.uid == myUid) {
            ref.document("$seat").delete()
            mySeat = null
            return
        }
        if (isi != null) return
        if (seat in locked && !akuOwner) return
        // Pindah kursi: hapus kursi lama dulu, baru tulis yang baru.
        mySeat?.let { lama -> if (lama != seat) ref.document("$lama").delete() }
        ref.document("$seat").set(
            mapOf(
                "uid" to myUid,
                "seat" to seat,
                "name" to nama,
                "micOn" to micOn,
                "updatedAt" to FieldValue.serverTimestamp(),
            )
        )
        mySeat = seat
        VoiceRoom.setMic(micOn)
    }

    fun kirim() {
        val isi = draft.trim()
        if (isi.isEmpty()) return
        draft = ""
        db.collection("rooms").document(room.id).collection("messages").add(
            mapOf(
                "text" to isi,
                "uid" to myUid,
                "senderId" to myUid,
                "name" to nama,
                "level" to 1,
                "dj" to false,
                "createdAt" to FieldValue.serverTimestamp(),
            )
        )
    }

    val listState = rememberLazyListState()

    Column(Modifier.fillMaxSize().padding(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Keluar", color = Muted, fontSize = 13.sp, modifier = Modifier.clickable { onBack() })
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(room.title, color = Color.White, fontWeight = FontWeight.Bold)
                Text(micMode, color = Muted, fontSize = 11.sp)
            }
            if (akuOwner) {
                Box(
                    Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(Card)
                        .clickable { showMode = true }
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                ) { Text("Mic $micMode", color = Pink, fontSize = 11.sp) }
            } else {
                Text(
                    if (VoiceRoom.ready) "Agora aktif" else "Agora belum aktif",
                    color = Pink,
                    fontSize = 11.sp,
                )
            }
        }

        Spacer(Modifier.height(10.dp))

        seatRows(micMode).forEach { jumlah ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                for (i in 1..jumlah) {
                    SeatCell(
                        label = seats[i]?.name ?: "",
                        mine = mySeat == i,
                        terkunci = i in locked,
                        onClick = {
                            val isi = seats[i]
                            if (isi != null && isi.uid != myUid) {
                                sheetSeat = isi
                            } else {
                                duduk(i)
                            }
                        },
                        onLongClick = {
                            if (akuOwner) {
                                val baru = if (i in locked) locked - i else locked + i
                                db.collection("rooms").document(room.id)
                                    .update("lockedSeats", baru.toList())
                            }
                        },
                    )
                }
            }
        }

        Spacer(Modifier.height(8.dp))

        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            state = listState,
            reverseLayout = true,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(pesan, key = { it.id }) { m ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
                        .background(Color.Black.copy(alpha = 0.32f)).padding(8.dp),
                ) {
                    Text(
                        m.name,
                        color = if (m.mine) Pink else Muted,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(m.text, color = Color.White, fontSize = 12.sp)
                }
            }
        }

        Spacer(Modifier.height(6.dp))

        if (showMode) {
            AlertDialog(
                onDismissRequest = { showMode = false },
                title = { Text("Jumlah kursi mic") },
                text = {
                    Column {
                        listOf("13 Mics", "11 Mics", "9 Mics").forEach { m ->
                            Text(
                                m,
                                color = if (m == micMode) Pink else Color.White,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        showMode = false
                                        db.collection("rooms").document(room.id)
                                            .update("micMode", m)
                                    }
                                    .padding(vertical = 10.dp),
                            )
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { showMode = false }) { Text("Tutup") }
                },
            )
        }

        sheetSeat?.let { orang ->
            AlertDialog(
                onDismissRequest = { sheetSeat = null },
                title = { Text(orang.name) },
                text = {
                    Column {
                        Text("Kursi ${orang.seat}", color = Muted, fontSize = 12.sp)
                        Spacer(Modifier.height(6.dp))
                        Text("ID: " + orang.uid.takeLast(6), color = Muted, fontSize = 12.sp)
                        if (orang.uid == ownerId) {
                            Spacer(Modifier.height(6.dp))
                            Text("Owner room", color = Pink, fontSize = 12.sp)
                        }
                    }
                },
                confirmButton = {
                    TextButton(onClick = { sheetSeat = null }) { Text("Tutup") }
                },
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(if (micOn) Pink else Color(0xFF2C1B42))
                    .clickable {
                        micOn = !micOn
                        VoiceRoom.setMic(micOn)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(if (micOn) "Mic" else "Mute", color = Color.White, fontSize = 11.sp)
            }
            Spacer(Modifier.width(8.dp))
            TextField(
                value = draft,
                onValueChange = { draft = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Tulis pesan", color = Muted, fontSize = 12.sp) },
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Card,
                    unfocusedContainerColor = Card,
                    focusedTextColor = Color.White,
                    unfocusedTextColor = Color.White,
                ),
            )
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier
                    .size(42.dp)
                    .clip(CircleShape)
                    .background(Pink)
                    .clickable { kirim() },
                contentAlignment = Alignment.Center,
            ) { Text("Kirim", color = Color.White, fontSize = 10.sp) }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SeatCell(
    label: String,
    mine: Boolean,
    terkunci: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .padding(3.dp)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
    ) {
        Box(
            Modifier
                .size(50.dp)
                .clip(CircleShape)
                .background(if (mine) Color(0xFF3A2154) else Card)
                .border(
                    if (terkunci) 2.dp else 1.dp,
                    if (terkunci) Pink.copy(alpha = 0.8f) else Color.White.copy(alpha = 0.12f),
                    CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                when {
                    terkunci && label.isBlank() -> "X"
                    label.isBlank() -> "+"
                    else -> label.take(1).uppercase()
                },
                color = if (label.isBlank()) Muted else Color.White,
                fontSize = 15.sp,
            )
        }
        Spacer(Modifier.height(3.dp))
        Text(
            if (label.isBlank()) "kosong" else label.take(7),
            color = if (mine) Pink else Muted,
            fontSize = 9.sp,
        )
    }
}
