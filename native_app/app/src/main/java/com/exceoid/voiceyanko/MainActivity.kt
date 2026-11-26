package com.exceoid.voiceyanko

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query

// ---------------------------------------------------------------- tema

private val BgTop = Color(0xFF1B0733)
private val BgBottom = Color(0xFF0D0418)
private val Surface1 = Color(0xFF241037)
private val Surface2 = Color(0xFF2E1444)
private val Pink = Color(0xFFFF4FA3)
private val Violet = Color(0xFF8B5CFF)
private val Gold = Color(0xFFFFC53D)
private val Muted = Color(0xFFB6A6CE)
private val Bg = BgBottom

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

private fun inisial(nama: String): String =
    nama.trim().take(1).uppercase().ifBlank { "?" }

class MainActivity : ComponentActivity() {
    private val micPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        VoiceRoom.init(this)
        if (VoiceRoom.ready) micPermission.launch(Manifest.permission.RECORD_AUDIO)
        val auth = FirebaseAuth.getInstance()
        if (auth.currentUser == null) auth.signInAnonymously()
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(primary = Pink, background = Bg, surface = Surface1),
            ) { AppRoot() }
        }
    }
}

@Composable
private fun Latar(isi: @Composable () -> Unit) {
    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(BgTop, BgBottom))),
    ) { isi() }
}

@Composable
private fun AppRoot() {
    var openRoom by remember { mutableStateOf<RoomRow?>(null) }
    val room = openRoom
    Latar {
        if (room == null) {
            PartyScreen(onOpen = { openRoom = it })
        } else {
            RoomScreen(room, onBack = { openRoom = null })
        }
    }
}

// ---------------------------------------------------------------- daftar room

@Composable
private fun PartyScreen(onOpen: (RoomRow) -> Unit) {
    var rooms by remember { mutableStateOf<List<RoomRow>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var tab by remember { mutableStateOf("Party") }

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

        // Banner ungu bergaya aplikasi lama.
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .height(96.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(Brush.horizontalGradient(listOf(Violet, Pink))),
        ) {
            Column(Modifier.padding(16.dp)) {
                Text("Party malam ini", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(4.dp))
                Text("Masuk room, naik mic, ngobrol bareng", color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp)
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
                loading -> Text("Memuat room...", color = Muted, fontSize = 12.sp, modifier = Modifier.padding(18.dp))
                rooms.isEmpty() -> Column(Modifier.padding(18.dp)) {
                    Text("Belum ada room", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    Text("Jadilah yang pertama membuat room", color = Muted, fontSize = 11.sp)
                }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        start = 16.dp, end = 16.dp, bottom = 12.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    items(rooms, key = { it.id }) { r -> RoomCard(r) { onOpen(r) } }
                }
            }
        }

        BottomBar(tab) { tab = it }
    }
}

@Composable
private fun RoomCard(r: RoomRow, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Surface1)
            .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Brush.verticalGradient(listOf(Violet, Pink))),
            contentAlignment = Alignment.Center,
        ) { Text(inisial(r.title), color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold) }

        Spacer(Modifier.width(12.dp))

        Column(Modifier.weight(1f)) {
            Text(r.title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(2.dp))
            Text(
                r.topic.ifBlank { "Tanpa topik" },
                color = Muted,
                fontSize = 11.sp,
                maxLines = 1,
            )
        }

        Row(
            Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(Pink.copy(alpha = 0.16f))
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("mic", color = Pink, fontSize = 9.sp)
            Spacer(Modifier.width(4.dp))
            Text("${r.listeners}", color = Pink, fontSize = 11.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun BottomBar(aktif: String, onPilih: (String) -> Unit) {
    val menu = listOf("Explore", "Moments", "Party", "Messages", "Me")
    Row(
        Modifier
            .fillMaxWidth()
            .background(Surface1.copy(alpha = 0.92f))
            .padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        menu.forEach { m ->
            val pilih = m == aktif
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable { onPilih(m) }) {
                Box(
                    Modifier
                        .size(24.dp)
                        .clip(CircleShape)
                        .background(if (pilih) Pink.copy(alpha = 0.22f) else Color.Transparent),
                    contentAlignment = Alignment.Center,
                ) { Text(m.take(1), color = if (pilih) Pink else Muted, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                Spacer(Modifier.height(2.dp))
                Text(m, color = if (pilih) Pink else Muted, fontSize = 9.sp)
            }
        }
    }
}

// ---------------------------------------------------------------- room

@OptIn(ExperimentalFoundationApi::class)
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
    var draft by remember { mutableStateOf("") }
    var subs by remember { mutableStateOf<List<ListenerRegistration>>(emptyList()) }
    var ownerId by remember { mutableStateOf("") }
    var locked by remember { mutableStateOf<Set<Int>>(emptySet()) }
    var sheetSeat by remember { mutableStateOf<Seat?>(null) }
    var showMode by remember { mutableStateOf(false) }
    val akuOwner = myUid.isNotEmpty() && myUid == ownerId

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
                if (n >= 0 && uid.isNotEmpty()) map[n] = Seat(n, uid, d.getString("name") ?: "User")
            }
            seats = map
        }
        list += roomRef.collection("messages")
            .orderBy("createdAt", Query.Direction.DESCENDING)
            .limit(50)
            .addSnapshotListener { snap, _ ->
                pesan = snap?.documents?.mapNotNull { d ->
                    val text = d.getString("text") ?: return@mapNotNull null
                    ChatMsg(d.id, d.getString("name") ?: "User", text, d.getString("uid") == myUid)
                } ?: emptyList()
            }
        subs = list
        if (VoiceRoom.ready) VoiceRoom.join(room.id, myUid)
    }

    DisposableEffect(room.id) {
        onDispose {
            subs.forEach { it.remove() }
            VoiceRoom.leave()
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

    Column(Modifier.fillMaxSize()) {
        // header
        Row(
            Modifier.fillMaxWidth().padding(start = 14.dp, end = 14.dp, top = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(Surface2)
                    .clickable { onBack() }
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) { Text("Keluar", color = Muted, fontSize = 11.sp) }

            Spacer(Modifier.width(10.dp))

            Column(Modifier.weight(1f)) {
                Text(room.title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                Text(micMode, color = Muted, fontSize = 10.sp)
            }

            if (akuOwner) {
                Box(
                    Modifier
                        .clip(RoundedCornerShape(10.dp))
                        .background(Surface2)
                        .clickable { showMode = true }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                ) { Text("Mic", color = Pink, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
            }
        }

        Spacer(Modifier.height(10.dp))

        // panggung kursi
        Box(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Surface1.copy(alpha = 0.75f))
                .border(1.dp, Color.White.copy(alpha = 0.06f), RoundedCornerShape(20.dp))
                .padding(vertical = 12.dp),
        ) {
            Column {
                Row(
                    Modifier.fillMaxWidth().padding(bottom = 8.dp),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    val host = seats[0]
                    SeatCircle(
                        nama = host?.name ?: "Owner",
                        mine = mySeat == 0,
                        terkunci = 0 in locked,
                        host = true,
                        onClick = {
                            if (host != null && host.uid != myUid) sheetSeat = host else duduk(0)
                        },
                        onLongClick = {
                            if (akuOwner) {
                                val baru = if (0 in locked) locked - 0 else locked + 0
                                db.collection("rooms").document(room.id).update("lockedSeats", baru.toList())
                            }
                        },
                    )
                }
                seatRows(micMode).forEach { jumlah ->
                    Row(
                        Modifier.fillMaxWidth().padding(vertical = 3.dp),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        for (i in 1..jumlah) {
                            val orang = seats[i]
                            SeatCircle(
                                nama = orang?.name ?: "",
                                mine = mySeat == i,
                                terkunci = i in locked,
                                host = false,
                                onClick = {
                                    if (orang != null && orang.uid != myUid) sheetSeat = orang else duduk(i)
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
            }
        }

        Spacer(Modifier.height(8.dp))

        // chat
        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp),
            state = listState,
            reverseLayout = true,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(pesan, key = { it.id }) { m -> ChatBubble(m) }
        }

        // bar bawah: mic + input
        Row(
            Modifier
                .fillMaxWidth()
                .background(Surface1.copy(alpha = 0.92f))
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(
                        when {
                            mySeat == null -> Brush.linearGradient(listOf(Surface2, Surface2))
                            micOn -> Brush.linearGradient(listOf(Violet, Pink))
                            else -> Brush.linearGradient(listOf(Surface2, Surface2))
                        },
                    )
                    .clickable {
                        micOn = !micOn
                        VoiceRoom.setMic(micOn)
                        mySeat?.let { s ->
                            db.collection("rooms").document(room.id).collection("seats")
                                .document("$s").update("micOn", micOn)
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    when {
                        mySeat == null -> "-"
                        micOn -> "mic"
                        else -> "off"
                    },
                    color = if (mySeat != null && micOn) Color.White else Muted,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                )
            }

            Spacer(Modifier.width(8.dp))

            Box(
                Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(20.dp))
                    .background(Surface2)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                if (draft.isEmpty()) {
                    Text("Tulis pesan", color = Muted, fontSize = 12.sp)
                }
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    singleLine = true,
                    textStyle = TextStyle(color = Color.White, fontSize = 12.sp),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.width(8.dp))

            Box(
                Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(Brush.horizontalGradient(listOf(Violet, Pink)))
                    .clickable { kirim() }
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) { Text("Kirim", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
        }
    }

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
                                    db.collection("rooms").document(room.id).update("micMode", m)
                                }
                                .padding(vertical = 10.dp),
                        )
                    }
                }
            },
            confirmButton = { TextButton(onClick = { showMode = false }) { Text("Tutup") } },
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
            confirmButton = { TextButton(onClick = { sheetSeat = null }) { Text("Tutup") } },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SeatCircle(
    nama: String,
    mine: Boolean,
    terkunci: Boolean,
    host: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
) {
    val kosong = nama.isBlank()
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .padding(3.dp)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick),
    ) {
        Box(
            Modifier
                .size(if (host) 58.dp else 50.dp)
                .clip(CircleShape)
                .background(
                    when {
                        !kosong -> Brush.linearGradient(listOf(Violet, Pink))
                        terkunci -> Brush.linearGradient(listOf(Surface2, Surface2))
                        else -> Brush.linearGradient(listOf(Surface2, Surface1))
                    },
                )
                .border(
                    width = if (mine) 2.dp else 1.dp,
                    color = when {
                        mine -> Pink
                        terkunci -> Gold.copy(alpha = 0.7f)
                        else -> Color.White.copy(alpha = 0.10f)
                    },
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                when {
                    kosong && terkunci -> "lock"
                    kosong -> "+"
                    else -> inisial(nama)
                },
                color = if (kosong) Muted else Color.White,
                fontSize = if (kosong) 13.sp else 18.sp,
                fontWeight = FontWeight.Bold,
            )
        }
        Spacer(Modifier.height(4.dp))
        Text(
            when {
                !kosong -> nama.take(7)
                host -> "Owner"
                else -> "kosong"
            },
            color = if (mine) Pink else Muted,
            fontSize = 9.sp,
            maxLines = 1,
        )
    }
}

@Composable
private fun ChatBubble(m: ChatMsg) {
    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = if (m.mine) Alignment.End else Alignment.Start,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (!m.mine) {
                Box(
                    Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(Brush.linearGradient(listOf(Violet, Pink))),
                    contentAlignment = Alignment.Center,
                ) { Text(inisial(m.name), color = Color.White, fontSize = 9.sp, fontWeight = FontWeight.Bold) }
                Spacer(Modifier.width(6.dp))
                Text(m.name, color = Muted, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
            }
        }
        Spacer(Modifier.height(2.dp))
        Box(
            Modifier
                .clip(RoundedCornerShape(14.dp))
                .background(
                    if (m.mine) Brush.linearGradient(listOf(Violet, Pink))
                    else Brush.linearGradient(listOf(Surface2, Surface2)),
                )
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) { Text(m.text, color = Color.White, fontSize = 12.sp) }
    }
}
