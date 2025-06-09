# 🤖 Bot Telegram Recap Garapan

Bot Telegram Recap Garapan adalah sistem otomatis yang dirancang khusus untuk **mengumpulkan, mengategorikan, dan merangkum** semua aktivitas garapan crypto/airdrop dari channel Telegram dalam format recap harian yang terstruktur.

- **Ringkasan Lengkap**: Semua garapan hari itu dalam satu pesan
- **Navigasi Mudah**: Link langsung ke post asli untuk detail lengkap
- **Tidak Ketinggalan**: Recap otomatis setiap hari jam 23:58 WIB
- **Akses Sosial Media**: Link langsung ke semua platform official

### **Monitoring Real-time (24/7)**
```
Channel Utama → Bot Monitor → Deteksi Hashtag → Kategorisasi → Simpan Data
```

### **Sistem Kategorisasi Cerdas**
Bot menggunakan **AI-like hashtag detection** dengan sistem prioritas:

| Prioritas | Kategori | Hashtag Trigger | Contoh |
|-----------|----------|-----------------|---------|
| 1 | 🏦 Garapan Landing | #landing, #cair, #jp | Post tentang pencairan/hasil |
| 2 | 🔗 Garapan Node | #node, #validator | Setup node/validator |
| 3 | 🧪 Garapan Testnet | #testnet | Testing blockchain baru |
| 4 | 📝 Garapan Whitelist | #whitelist, #WL, #waitlist | Pendaftaran whitelist |
| 5 | 🏆 Garapan Airdrop Bot | #airdrop, #bot, #gleam | Bot tasks & campaigns |
| 6 | ⏰ Garapan Update | #update, #news, #info | Berita & update |

### **Proses Recap Otomatis**
```
23:58 WIB → Kumpulkan Data → Format HTML → Kirim ke Relay → Reset Data → Siap Hari Berikutnya
```

## **📋 Cara Install**

### **1. Set Domain**

Buat Domain di [Hostinger](https://hostinger.co.id?REFERRALCODE=A5NCOINNYGJ7]) Cuma 30 Rebuan Setahun

- Type : A
- Name : Name (Misalkan Airdrop)
- Points to : IP-VPS
- TTL : 300

Noted : Simpan nama Domain Kalian Misalkan airdrop.bangpateng.xyz

### **2. Install di VPS**

- Belum Punya VPS
- Buy di : [VPS Murah](https://www.databasemart.com/?aff_id=8d846344eed94bd4ab61b0acda370477])
- Open VPS Kamu

```
git clone https://github.com/bangpateng/rekap/tree/main
cd rekap
```

```
npm i
```

### **3. Buat Bot di Bot Father**

- Open Link : https://t.me/BotFather
- /Start dan Ketik /newbot
- Buat Nama Bot dan Username Bot
- Copy Token Bot dan Username Bot
- Done

## **4. Set di Channel Utama dan Channel Relay**

- Add Username Bot Yang Kalian Buat jadi Kan Admin di Channel Utama dan Channel Relay (Channel Kedua) Untuk Menerima Hasil Rekap Setiap Hari
- Ambil ID Masing Masing Channel (Example : -998267412) Tanya di Chat GPT Caranya Ambilnya
- Dan Simpan Kedua Channel ID Tersebut
- Done

### **5. Kembali ke VPS**

```
chmod +x instal.sh
./instal.sh
```

- Masukan Data Data Tadi Yang Sudah Kalian Simpan Ada 4 di Antaranya `Nama Website` `Bot Token dari Bot Father` `ID Channel Utama` `ID Channel Relay`
- Lanjutkan
- Done

```
#check status
systemctl status telegrambot.service
```

```
#Restart
sudo systemctl restart telegrambot.service
```

### **6. Test (Untuk Memastikan Rekap Berjalan Dengan Baik)**

- Buat Postingan di Channel Utama (Setiap Postingan Gunakan #hastag
- Contoh :

```
The Nativ Outpost — Flash Launch Event
35,000,000 $NTV in rewards.

Claim OAT : https://app.galxe.com/quest/Nativ/GCmBdtffhU 

#Airdrop
```

- Ke VPS Coba Paste Command

```
curl http://localhost:5555/test-recap
```

- Check Ke Channel Relay (Channel Kedua) Untuk Menerima Hasil Rekap
- Done, Jika Masuk Hasilnya
- Congratss Selesai dan Kamu Tidak Perlu Manual lagi Yaa banggg

**Disclaimer :** Tetap Jaga Keamanan Token Bot Father Kalian Agar Tidak di Salahgunakan Orang Lain 

**Thanks To ❤️ [@bgpateng](https://t.me/bg_pateng)**

