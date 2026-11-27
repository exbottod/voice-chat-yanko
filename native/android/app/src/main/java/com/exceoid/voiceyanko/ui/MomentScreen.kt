package com.exceoid.voiceyanko.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.auravox.app.R
import com.exceoid.voiceyanko.Aset
import com.exceoid.voiceyanko.Muted

@Composable
internal fun MomentScreen() {
    Column(Modifier.fillMaxSize()) {
        Text(
            "Moments",
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.ExtraBold,
            modifier = Modifier.fillMaxWidth().padding(start = 18.dp, top = 16.dp, bottom = 8.dp),
        )
        Column(
            Modifier.fillMaxSize().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Aset(R.drawable.tabs_moments_off_v2, Modifier.size(64.dp), 0.5f)
            Spacer(Modifier.height(14.dp))
            Text("Belum ada momen", color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(4.dp))
            Text("Bagikan momen pertamamu dari room", color = Muted, fontSize = 11.sp)
        }
    }
}
