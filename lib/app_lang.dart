import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:shared_preferences/shared_preferences.dart';

/// Bahasa aplikasi. Teks sumber ditulis dalam Bahasa Indonesia; saat bahasa lain
/// dipilih, setiap teks diterjemahkan lewat kamus.
class AppLang {
  AppLang._();

  static const String _key = 'lang';
  static final ValueNotifier<String> current =
      ValueNotifier<String>('Bahasa Indonesia');

  static bool get isEnglish => current.value == 'English';

  static Future<void> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    current.value = p.getString(_key) ?? 'Bahasa Indonesia';
  }

  static Future<void> set(String lang) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_key, lang);
    current.value = lang;
  }

  /// Terjemahkan satu teks. Mengembalikan teks asli bila belum ada padanannya.
  static String tr(String text) {
    if (!isEnglish || text.isEmpty) {
      return text;
    }
    final String? direct = _en[text];
    if (direct != null) {
      return direct;
    }
    for (final List<Object> rule in _rules) {
      final RegExp re = rule[0] as RegExp;
      final RegExpMatch? m = re.firstMatch(text);
      if (m != null) {
        return (rule[1] as String Function(RegExpMatch)).call(m);
      }
    }
    return text;
  }

  static final List<List<Object>> _rules = <List<Object>>[
    <Object>[
      RegExp(r'^Lencana (\w+) dan bingkai eksklusif (\w+)$'),
      (RegExpMatch m) => '${m[1]} badge and exclusive ${m[2]} frame',
    ],
    <Object>[
      RegExp(r'^Banner (\w+) beranimasi saat kamu masuk room$'),
      (RegExpMatch m) => 'Animated ${m[1]} banner when you enter a room',
    ],
    <Object>[
      RegExp(r'^Semua keistimewaan privasi (\w+)$'),
      (RegExpMatch m) => 'All ${m[1]} privacy privileges',
    ],
    <Object>[
      RegExp(r'^Lencana VIP(\d)$'),
      (RegExpMatch m) => 'VIP${m[1]} badge',
    ],
    <Object>[
      RegExp(r'^Bingkai VIP(\d)(.*)$'),
      (RegExpMatch m) => 'VIP${m[1]} frame${m[2]}',
    ],
    <Object>[
      RegExp(r'^Hari ke-(\d)$'),
      (RegExpMatch m) => 'Day ${m[1]}',
    ],
    <Object>[
      RegExp(r'^Habiskan ([\d.,]+) koin lagi untuk (.+?) \((.+)\)$'),
      (RegExpMatch m) => 'Spend ${m[1]} more coins to reach ${m[2]} (${m[3]})',
    ],
    <Object>[
      RegExp(r'^([\d.,]+) koin lagi ke level berikutnya$'),
      (RegExpMatch m) => '${m[1]} coins to the next level',
    ],
    <Object>[
      RegExp(r'^Rangkaian check-in (\d+) hari$'),
      (RegExpMatch m) => '${m[1]}-day check-in streak',
    ],
    <Object>[
      RegExp(r'^Diperoleh hari ini: (\d+) koin$'),
      (RegExpMatch m) => 'Earned today: ${m[1]} coins',
    ],
    <Object>[
      RegExp(r'^Reset dalam (.+) · reward dibayarkan dalam koin$'),
      (RegExpMatch m) => 'Resets in ${m[1]} · rewards are paid in coins',
    ],
    <Object>[
      RegExp(r'^Berakhir dalam (.+)$'),
      (RegExpMatch m) => 'Ends in ${m[1]}',
    ],
    <Object>[
      RegExp(r'^Jadi (\w+) · ([\d.,]+) koin$'),
      (RegExpMatch m) => 'Become ${m[1]} · ${m[2]} coins',
    ],
    <Object>[
      RegExp(r'^Check-in berhasil, \+(\d+) koin$'),
      (RegExpMatch m) => 'Check-in successful, +${m[1]} coins',
    ],
    <Object>[
      RegExp(r'^Versi (.+)$'),
      (RegExpMatch m) => 'Version ${m[1]}',
    ],
    <Object>[
      RegExp(r'^([\d.,]+) koin$'),
      (RegExpMatch m) => '${m[1]} coins',
    ],
    <Object>[
      RegExp(r'^(\d+) hari$'),
      (RegExpMatch m) => '${m[1]} days',
    ],
    <Object>[
      RegExp(r'^(\d+) mnt$'),
      (RegExpMatch m) => '${m[1]} min',
    ],
  ];

  static const Map<String, String> _en = <String, String>{
    // Umum
    'Voice Chat Yanko': 'Voice Chat Yanko',
    'Jelajahi': 'Explore',
    'Momen': 'Moments',
    'Party': 'Party',
    'Pesan': 'Messages',
    'Saya': 'Me',
    'Untukmu': 'For you',
    'Mengikuti': 'Following',
    'Nanti': 'Later',
    'Update sekarang': 'Update now',
    'Update tersedia': 'Update available',
    'Versi baru sudah terbit.': 'A new version is available.',
    'Simpan': 'Save',
    'Keluar': 'Log out',
    'Keluar?': 'Log out?',
    'Batal': 'Cancel',
    'Hapus': 'Delete',
    'Mengerti': 'Got it',
    'Kirim': 'Send',
    'Ayo': 'Go',
    'Hari ini': 'Today',
    'Minggu ini': 'This week',
    'Bulan ini': 'This month',
    'Harian': 'Daily',
    'Mingguan': 'Weekly',
    'Bulanan': 'Monthly',
    'Belum ada': 'None yet',
    'Tidak ada': 'None',
    'Default': 'Default',
    'Semua orang': 'Everyone',
    'Teman saja': 'Friends only',
    'Sekali saja': 'One time only',
    // Login & daftar
    'Google Login': 'Google Login',
    'Daftar akun': 'Sign up',
    'Login dibatalkan': 'Login cancelled',
    'Firebase belum aktif': 'Firebase is not active yet',
    'Chat suara, teman baru, room seru.': 'Voice chat, new friends, fun rooms.',
    'Isi nama dan nomor HP untuk mulai ngobrol di voice room.':
        'Enter your name and phone number to start chatting in voice rooms.',
    'Nama dan nomor HP wajib diisi': 'Name and phone number are required',
    'Nama kamu': 'Your name',
    'Nomor HP': 'Phone number',
    'Saya setuju dengan Terms of Service dan Privacy Policy':
        'I agree to the Terms of Service and Privacy Policy',
    'Centang persetujuan Terms of Service dulu ya':
        'Please accept the Terms of Service first',
    'By continuing , you agree to our ': 'By continuing, you agree to our ',
    ' and ': ' and ',
    'Terms of Service': 'Terms of Service',
    'Privacy Policy': 'Privacy Policy',
    // Buat profil
    'Buat profilmu': 'Create your profile',
    'Beberapa detail agar kami bisa mengenalmu':
        'A few details so we can get to know you',
    'Tambah foto': 'Add photo',
    'Nama panggilan': 'Nickname',
    'Kami harus memanggilmu apa?': 'What should we call you?',
    'Gender': 'Gender',
    'Wanita': 'Female',
    'Pria': 'Male',
    'Gender dan tanggal lahir tidak dapat diubah nanti.':
        'Gender and date of birth cannot be changed later.',
    'Tanggal lahir': 'Date of birth',
    'Kode undangan (opsional)': 'Invite code (optional)',
    'Kode 8 digit temanmu': "Your friend's 8-digit code",
    'Kode agensi (opsional)': 'Agency code (optional)',
    'Mulai': 'Start',
    'Jika temanmu mengundangmu, masukkan kodenya; setelah kamu ':
        'If a friend invited you, enter their code; after you ',
    'melengkapi profil dan masuk selama 2 hari, kalian berdua dapat koin.':
        'complete your profile and sign in for 2 days, you both get coins.',
    // Tab Saya
    'Lengkapi untuk mendapat 100 koin': 'Complete to earn 100 coins',
    'Kelengkapan profil': 'Profile completion',
    'Profilmu sudah lengkap': 'Your profile is complete',
    'Berikutnya: Foto profil': 'Next: Profile photo',
    'Lihat atau edit': 'View or edit',
    'Dompet': 'Wallet',
    'Gabung ›': 'Join ›',
    'VIP & SVIP': 'VIP & SVIP',
    'Misi': 'Missions',
    'Peringkat': 'Rankings',
    'Bangsawan': 'Nobility',
    'Pengunjung': 'Visitors',
    'Edit profil': 'Edit profile',
    'Undang teman': 'Invite friends',
    'Keluargaku': 'My family',
    'Segera': 'Soon',
    'Agensiku': 'My agency',
    'Perlengkapan': 'Inventory',
    'Hewan peliharaanku': 'My pets',
    'Levelku': 'My level',
    'Pusat verifikasi': 'Verification center',
    'Belum terverifikasi': 'Not verified',
    'Bagikan': 'Share',
    'Setelan': 'Settings',
    // Profil
    'Tentang': 'About',
    'Hubungan': 'Relationships',
    'Penghargaan': 'Honors',
    'Album profil': 'Profile album',
    'Album pribadi': 'Private album',
    'Terlihat oleh semua orang.': 'Visible to everyone.',
    'Terlihat oleh orang dengan level keakraban 10 atau lebih tinggi.':
        'Visible to people with closeness level 10 or higher.',
    'Belum ada hubungan': 'No relationships yet',
    'Belum ada penghargaan': 'No honors yet',
    'Belum ada momen': 'No moments yet',
    'Online': 'Online',
    // Edit profil
    'Info dasar': 'Basic info',
    'Foto profil': 'Profile photo',
    '3 foto album': '3 album photos',
    'Tentang saya': 'About me',
    'Perkenalan suara': 'Voice intro',
    'Foto unggulan': 'Featured photo',
    'Verifikasi orang asli': 'Real person verification',
    'Tinggi (cm)': 'Height (cm)',
    'Pekerjaan': 'Occupation',
    'Negara / kota': 'Country / city',
    'Bio': 'Bio',
    'Ceritakan sedikit tentang dirimu': 'Tell us a little about yourself',
    'Tambah': 'Add',
    // Party & tab
    'Belum ada room terbuka': 'No open rooms yet',
    'Room dibuka oleh pemilik agensi. Room yang terbuka akan muncul di sini':
        'Rooms are opened by agency owners. Open rooms will appear here',
    'Pilih room dan mulai ngobrol': 'Pick a room and start chatting',
    'Belum ada yang bisa dijelajahi': 'Nothing to explore yet',
    'Orang dan room menarik akan muncul di sini':
        'Interesting people and rooms will appear here',
    'Bagikan momen pertamamu dan lihat momen temanmu':
        'Share your first moment and see your friends\' moments',
    'Belum ada pesan': 'No messages yet',
    'Percakapanmu dengan teman akan muncul di sini':
        'Your conversations with friends will appear here',
    // Setelan
    'Bahasa': 'Language',
    'Sapaan': 'Greeting',
    'Halo!': 'Hello!',
    'Hai, apa kabar?': 'Hi, how are you?',
    'Selamat datang!': 'Welcome!',
    'Mode Lite': 'Lite mode',
    'Hemat data dan baterai: lebih sedikit animasi berat, thumbnail lebih kecil. Suara dan panggilan tidak berubah.':
        'Save data and battery: fewer heavy animations, smaller thumbnails. Voice and calls are unchanged.',
    'Privasi': 'Privacy',
    'Siapa yang bisa menelepon saya': 'Who can call me',
    'Pengguna yang diblokir': 'Blocked users',
    'Belum ada pengguna yang diblokir': 'No blocked users yet',
    'Masukkan ID pengguna': 'Enter user ID',
    'Panggilan suara dan video tidak direkam. Orang yang kamu blokir tidak akan pernah bisa menelepon mu.':
        'Voice and video calls are not recorded. People you block can never call you.',
    'Keistimewaan privasi': 'Privacy privileges',
    'SVIP / Bangsawan': 'SVIP / Nobility',
    'Kunjungan tak terlihat': 'Invisible visits',
    'Masuk room tak terlihat': 'Invisible room entry',
    'Status online tak terlihat': 'Invisible online status',
    'Tersembunyi di peringkat': 'Hidden from rankings',
    'Kunjungan dan masuk room tak terlihat': 'Invisible visits and room entry',
    'Ketuk baris untuk melihat detail dan keanggotaan yang diperlukan. Setelan ini berhenti berfungsi otomatis saat keanggotaanmu berakhir.':
        'Tap a row to see details and the required membership. These settings stop working automatically when your membership ends.',
    'Akun': 'Account',
    'Email': 'Email',
    'Ubah kata sandi': 'Change password',
    'Hapus cache': 'Clear cache',
    'Hapus cache?': 'Clear cache?',
    'Cache dihapus': 'Cache cleared',
    'Akun ini masuk dengan Google, jadi tidak memakai kata sandi.':
        'This account signs in with Google, so it has no password.',
    'Izin saya': 'My permissions',
    'Bantu kami meningkatkan aplikasi (pengukuran)':
        'Help us improve the app (analytics)',
    'Ini opsional: kamu bisa memakai aplikasi dengan cara yang sama tanpa semua ini dan mengubahnya kapan saja di Pengaturan.':
        'This is optional: you can use the app the same way without it and change it any time in Settings.',
    'Hukum': 'Legal',
    'Kebijakan Privasi': 'Privacy Policy',
    'Ketentuan Penggunaan': 'Terms of Use',
    'Nilai Yanko': 'Rate Yanko',
    'Kirim masukan': 'Send feedback',
    'Kirim masukan ke developerex100@gmail.com':
        'Send feedback to developerex100@gmail.com',
    'Tentang Yanko': 'About Yanko',
    'Tentang Voice Chat Yanko': 'About Voice Chat Yanko',
    'Hapus akun': 'Delete account',
    'Hapus akun?': 'Delete account?',
    'Akun dan profilmu akan dihapus permanen dan tidak bisa dikembalikan.':
        'Your account and profile will be deleted permanently and cannot be restored.',
    'Demi keamanan, keluar lalu masuk lagi sebelum menghapus akun.':
        'For security, log out and sign in again before deleting your account.',
    'Kamu akan keluar dari akun ini.': 'You will be logged out of this account.',
    'Penghapusan akun': 'Account deletion',
    'Kontak': 'Contact',
    'Pengembang': 'Developer',
    'Lisensi open source': 'Open source licenses',
    'Voice Chat Yanko dibuat dengan Flutter, Firebase, dan komponen ':
        'Voice Chat Yanko is built with Flutter, Firebase, and other ',
    'open source lain. Perangkat lunak ini didistribusikan di bawah ':
        'open source components. This software is distributed under ',
    'lisensi MIT, Apache 2.0, dan BSD; hak cipta milik pemiliknya ':
        'the MIT, Apache 2.0, and BSD licenses; copyright belongs to ',
    'masing-masing.': 'their respective owners.',
    '© 2026 Voice Chat Yanko': '© 2026 Voice Chat Yanko',
    // Undang teman
    'Undang teman, untung bersama': 'Invite friends, win together',
    'Ajak teman-temanmu ke Yanko dan kumpulkan reward bersama.':
        'Invite your friends to Yanko and earn rewards together.',
    'Kode undanganmu': 'Your invite code',
    'Salin kode': 'Copy code',
    'Kode disalin': 'Code copied',
    'ID disalin': 'ID copied',
    'Cara kerjanya': 'How it works',
    'Bagikan kodemu': 'Share your code',
    'Temanmu memasukkannya': 'Your friend enters it',
    'Reward setelah 2 hari aktif': 'Reward after 2 active days',
    'Temanmu memasukkan kodemu saat mendaftar, atau dalam 7 hari setelahnya, lewat Saya › Undang teman.':
        'Your friend enters your code when signing up, or within 7 days after, via Me › Invite friends.',
    'Reward': 'Reward',
    'Kamu': 'You',
    'Temanmu': 'Your friend',
    'wanita mendapat 800': 'women get 800',
    'Total diperoleh': 'Total earned',
    'Diundang': 'Invited',
    'Batas bulanan': 'Monthly limit',
    'Kamu bisa mendapat reward untuk maksimal 30 undangan per bulan. Kamu tidak bisa memakai kodemu sendiri; reward dari akun palsu atau ganda akan ditarik kembali.':
        'You can earn rewards for up to 30 invites per month. You cannot use your own code; rewards from fake or duplicate accounts will be reversed.',
    'Punya kode undangan?': 'Have an invite code?',
    'Masukkan kode 8 digit temanmu dan kalian berdua akan mendapat reward.':
        "Enter your friend's 8-digit code and you both get a reward.",
    'Kode undangan': 'Invite code',
    'Kode terkirim': 'Code submitted',
    'Kode undangan harus 8 digit': 'Invite code must be 8 digits',
    'Kamu tidak bisa memakai kodemu sendiri': 'You cannot use your own code',
    'Orang yang kamu undang': 'People you invited',
    'Belum ada yang bergabung dengan kodemu. Bagikan untuk memulai!':
        'Nobody has joined with your code yet. Share it to get started!',
    // VIP
    'total pengeluaran': 'total spent',
    'Total pengeluaran': 'Total spent',
    'Lencana VIP': 'VIP badge',
    'Lihat masuk megah': 'Watch grand entrance',
    'Tingkat': 'Tiers',
    'Lencana level': 'Level badge',
    'Lihat semua pengunjung': 'See all visitors',
    'Lihat semua yang mengunjungi profilmu': 'See everyone who visited your profile',
    'Nama emas di room dan chat': 'Golden name in rooms and chat',
    'Gelembung chat VIP': 'VIP chat bubble',
    'Efek masuk beranimasi di room': 'Animated entrance effect in rooms',
    'Efek masuk beranimasi layar penuh saat kamu masuk room':
        'Full-screen animated entrance effect when you enter a room',
    'Kamu sudah mencapai VIP tertinggi': 'You have reached the highest VIP',
    '• VIP tidak dibeli: VIP diraih permanen dari total koin yang kamu belanjakan sejak bergabung, dan tidak pernah turun.':
        '• VIP cannot be bought: it is earned permanently from the total coins you have spent since joining, and never goes down.',
    '• Yang dihitung: hadiah, pesan, panggilan, toko barang, dan Bangsawan. Menukar berlian ke koin tidak dihitung.':
        '• What counts: gifts, messages, calls, the item store, and Nobility. Exchanging diamonds for coins does not count.',
    // Bangsawan
    'Pilih tingkat; keistimewaanmu aktif selama 30 hari.':
        'Pick a tier; your privileges stay active for 30 days.',
    'Banner masuk room': 'Room entry banner',
    ' masuk ke room': ' entered the room',
    'Semua keistimewaan Bangsawan': 'All Nobility privileges',
    'Pembelian bangsawan belum tersedia di versi ini.':
        'Nobility purchase is not available in this version.',
    '/ 30 hari': '/ 30 days',
    'Membeli tingkat yang sama lagi memperpanjangnya 30 hari. ':
        'Buying the same tier again extends it by 30 days. ',
    'Jika naik tingkat, sisa waktumu dipindahkan ke tingkat baru ':
        'If you upgrade, your remaining time moves to the new tier ',
    'sebanding dengan harga. Kamu bisa mengaktifkan mode tak ':
        'in proportion to the price. You can enable invisible ',
    'terlihat di Setelan → Privasi.': 'mode in Settings → Privacy.',
    // Peringkat
    'Kekayaan': 'Wealth',
    'Pesona': 'Charm',
    'Room': 'Room',
    'Aturan reward': 'Reward rules',
    'Belum ada siapa pun di sini pada periode ini':
        'Nobody is here for this period yet',
    'Masuk peringkat lewat pesan, panggilan, atau hadiah.':
        'Get ranked through messages, calls, or gifts.',
    'Kamu tidak masuk peringkat periode ini': "You're not ranked this period",
    'Peringkat dihitung dari aktivitas selama periode berjalan: ':
        'Rankings are based on activity during the current period: ',
    'pesan, panggilan, dan hadiah. Reward diberikan setelah periode berakhir ':
        'messages, calls, and gifts. Rewards are given after the period ends ',
    'kepada peringkat teratas.': 'to the top-ranked users.',
    // Misi
    'CHECK-IN\nHARIAN': 'DAILY\nCHECK-IN',
    'Reward check-in harian': 'Daily check-in reward',
    'Klaim reward hari ini': "Claim today's reward",
    'Reward hari ini sudah diklaim · kembali besok':
        "Today's reward claimed · come back tomorrow",
    'Kirim pesan ke wanita': 'Send messages to women',
    'Bicara lewat suara/video': 'Talk via voice/video',
    '0 mnt / 30 mnt': '0 min / 30 min',
    '5 mnt': '5 min',
    '15 mnt': '15 min',
    '30 mnt': '30 min',
    'Misi anggota baru': 'New member missions',
    'Lengkapi profilmu': 'Complete your profile',
    'Tambahkan foto profil dan isi nama, gender, dan tanggal lahirmu':
        'Add a profile photo and fill in your name, gender, and date of birth',
    'Tambahkan 3 foto album': 'Add 3 album photos',
    'Tambahkan minimal 3 foto ke albummu': 'Add at least 3 photos to your album',
    'Tulis bio-mu': 'Write your bio',
    'Tulis beberapa kalimat tentang dirimu di profil':
        'Write a few sentences about yourself on your profile',
    'Isi ulang koin pertama': 'First coin top-up',
    'Lakukan isi ulang pertamamu di toko koin':
        'Make your first top-up in the coin store',
    'Misi mingguan belum tersedia': 'Weekly missions are not available yet',
    'Misi bulanan belum tersedia': 'Monthly missions are not available yet',
    'Progres misi dihitung di server dari aktivitas nyatamu. Waktu reset ':
        'Mission progress is calculated on the server from your real activity. Reset time ',
    'adalah 03:00. Misi harian direset setiap hari, misi mingguan pada hari ':
        'is 03:00. Daily missions reset every day, weekly missions on ',
    'Senin, dan misi bulanan pada tanggal 1 setiap bulan. Hadiah tiap ':
        'Monday, and monthly missions on the 1st of each month. Rewards for each ',
    'tingkat diambil terpisah.': 'tier are claimed separately.',
    // Level
    'Level Kekayaan': 'Wealth Level',
    'Level saat ini': 'Current level',
    'Keuntungan': 'Benefits',
    'Menampilkan tingkat levelmu di samping nama...':
        'Shows your level next to your name...',
    'Menampilkan tingkat levelmu di samping nama':
        'Shows your level next to your name',
    'Gelembung chat': 'Chat bubble',
    'Pesanmu muncul dalam gelembung khusus':
        'Your messages appear in a special bubble',
    'Pengumuman naik level': 'Level-up announcement',
    'Semua orang tahu saat kamu naik level': 'Everyone knows when you level up',
    'Bingkai avatar': 'Avatar frame',
    'Hias avatarmu dan tampil beda': 'Decorate your avatar and stand out',
    'Warna nama': 'Name color',
    'Namamu tampil berwarna dengan cahaya': 'Your name glows in color',
    'Efek masuk': 'Entrance effect',
    'Masukmu ke room menarik semua perhatian':
        'Your room entrance grabs everyone\'s attention',
    'Hadiah koin': 'Coin reward',
    'Koin ditambahkan saat kamu naik level': 'Coins are added when you level up',
    'Keistimewaan khusus': 'Special privileges',
    'Hak istimewa tambahan untuk levelmu': 'Extra privileges for your level',
    'Segera hadir lebih banyak': 'More coming soon',
    'Nantikan keuntungan lainnya': 'Stay tuned for more benefits',
    'Cara naik level': 'How to level up',
    'Belanjakan koin': 'Spend coins',
    'Setiap koin yang kamu belanjakan bernilai 1 poin':
        'Every coin you spend is worth 1 point',
    'Kirim hadiah': 'Send gifts',
    'Kirim hadiah di chat atau room': 'Send gifts in chat or rooms',
    'Level tidak bernilai yang hadiah ditambahkan ke akunmu otomatis saat kamu naik level.':
        'Level rewards are added to your account automatically when you level up.',
    // Dompet
    'Saldo koin': 'Coin balance',
    'Isi ulang': 'Top up',
    'Isi ulang koin': 'Top up coins',
    'Isi ulang koin belum tersedia': 'Coin top-up is not available yet',
    'Riwayat transaksi': 'Transaction history',
    // Toko
    'Toko barang': 'Item store',
    'Barangku': 'My items',
    'Bingkai': 'Frames',
    'Efek nama': 'Name effects',
    'Efek ID': 'ID effects',
    'ID unik': 'Unique ID',
    'Kartu profil': 'Profile cards',
    'Beli dengan koin': 'Buy with coins',
    'Khusus VIP': 'VIP only',
    'Belum ada barang': 'No items yet',
    'Barang akan muncul di sini setelah ditambahkan.':
        'Items will appear here once they are added.',
    // Pengunjung
    'Belum ada yang mengunjungi profilmu': 'Nobody has visited your profile yet',
    'Gelembung chat ruang pesta': 'Party room chat bubble',
  };
}


/// Pengganti Text bawaan: terjemahkan otomatis dan perbarui saat bahasa berubah.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textScaler,
  }) : span = null;

  const Text.rich(
    InlineSpan this.span, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textScaler,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextScaler? textScaler;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLang.current,
      builder: (BuildContext context, String lang, Widget? child) {
        if (span != null) {
          return m.Text.rich(
            _translateSpan(span!),
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
            textScaler: textScaler,
          );
        }
        return m.Text(
          AppLang.tr(data ?? ''),
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          textScaler: textScaler,
        );
      },
    );
  }
}


InlineSpan _translateSpan(InlineSpan span) {
  if (span is TextSpan) {
    return TextSpan(
      text: span.text == null ? null : AppLang.tr(span.text!),
      children: span.children?.map(_translateSpan).toList(),
      style: span.style,
      recognizer: span.recognizer,
      semanticsLabel: span.semanticsLabel,
    );
  }
  return span;
}
