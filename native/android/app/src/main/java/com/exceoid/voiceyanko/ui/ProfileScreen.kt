package com.exceoid.voiceyanko.ui

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.exceoid.voiceyanko.Gold
import com.exceoid.voiceyanko.Muted
import com.exceoid.voiceyanko.Pink
import com.exceoid.voiceyanko.Surface1
import com.exceoid.voiceyanko.Violet
import com.exceoid.voiceyanko.inisial
import com.google.firebase.auth.FirebaseAuth

/// Tab profil: identitas, ringkasan angka, dan menu akun.
@Composable
fun ProfileScreen() {
    val u = FirebaseAuth.getInstance().currentUser
    val nama = u?.displayName ?: "Tamu"
    Column(Modifier.fillMaxSize().padding(18.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(62.dp)
                    .clip(CircleShape)
                    .background(Brush.linearGradient(listOf(Violet, Pink))),
                contentAlignment = Alignment.Center,
            ) { Text(inisial(nama), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Bold) }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(nama, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("ID: " + (u?.uid?.takeLast(6) ?: "-"), color = Muted, fontSize = 11.sp)
            }
        }

        Spacer(Modifier.height(16.dp))

        Row(
            Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .background(Surface1)
                .padding(14.dp),
            horizontalArrangement = Arrangement.SpaceAround,
        ) {
            listOf("Koin", "Level", "Pengikut").forEach { label ->
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("0", color = Gold, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    Text(label, color = Muted, fontSize = 10.sp)
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        listOf("Dompet", "Ranking", "VIP", "Tugas harian").forEach { menu ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Surface1)
                    .padding(horizontal = 14.dp, vertical = 13.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(menu, color = Color.White, fontSize = 13.sp)
                Spacer(Modifier.weight(1f))
                Text("segera", color = Muted, fontSize = 10.sp)
            }
        }
    }
}
