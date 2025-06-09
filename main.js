require('dotenv').config();
const axios = require('axios');
const moment = require('moment-timezone');
const fs = require('fs');
const FormData = require('form-data');
const express = require('express');
const app = express();

// Konstanta dan konfigurasi
const BOT_TOKEN = process.env.BOT_TOKEN;
const CHANNEL_ID = process.env.CHANNEL_ID;
const RELAY_CHANNEL_ID = process.env.RELAY_CHANNEL_ID; 
const TELEGRAM_API = `https://api.telegram.org/bot${BOT_TOKEN}`;
const WEBHOOK_URL = process.env.WEBHOOK_URL;
const PORT = 5555;
const POSTS_FILE = './rekap_telegram.json';
const LOG_FILE = './output.log';
const CATEGORIES_CONFIG_FILE = './kategory.json';
const SOCIAL_MEDIA_CONFIG_FILE = './socialmedia.json';

// Fungsi untuk log dengan timestamp
function logMessage(message) {
  const timestamp = moment().tz("Asia/Jakarta").format('YYYY-MM-DD HH:mm:ss');
  const logEntry = `[${timestamp}] ${message}`;
  console.log(logEntry);
  fs.appendFileSync(LOG_FILE, logEntry + '\n');
}

// Load kategori dari file config
function loadCategoriesConfig() {
  try {
    if (fs.existsSync(CATEGORIES_CONFIG_FILE)) {
      const config = JSON.parse(fs.readFileSync(CATEGORIES_CONFIG_FILE, 'utf8'));
      return config.categories;
    }
  } catch (error) {
    logMessage(`Error membaca categories config: ${error.message}`);
  }
  
  // Fallback default categories
  return {
    "Garapan Testnet": {
      "emoji": "&#128138;",
      "hashtags": ["#testnet", "#Testnet"]
    },
    "Garapan Whitelist": {
      "emoji": "&#128218;",
      "hashtags": ["#whitelist", "#Whitelist", "#waitlist", "#Waitlist", "#WL", "#wl"]
    },
    "Garapan Airdrop Bot and Gleam": {
      "emoji": "&#127942;",
      "hashtags": ["#airdrop", "#Airdrop", "#bot", "#Bot", "#gleam", "#Gleam", "#depin", "#Depin"]
    },
    "Garapan Node": {
      "emoji": "&#128421;",
      "hashtags": ["#node", "#Node", "#validator", "#Validator"]
    },
    "Garapan Update": {
      "emoji": "&#9203;",
      "hashtags": ["#update", "#Update", "#news", "#News", "#info", "#Info"]
    },
    "Garapan Landing": {
      "emoji": "&#128176;",
      "hashtags": ["#landing", "#Landing", "#cair", "#Cair", "#jp", "#JP", "#Jp"]
    }
  };
}

// Load social media dari file config
function loadSocialMediaConfig() {
  try {
    if (fs.existsSync(SOCIAL_MEDIA_CONFIG_FILE)) {
      const config = JSON.parse(fs.readFileSync(SOCIAL_MEDIA_CONFIG_FILE, 'utf8'));
      return config.socialMedia;
    }
  } catch (error) {
    logMessage(`Error membaca social media config: ${error.message}`);
  }
  
  // Fallback default social media
  return {
    title: "Official Sosial Media",
    titleEmoji: "&#127760;",
    links: [
      { name: "Youtube Channel", url: "https://www.youtube.com/@BangPateng/", emoji: "&#128250;" },
      { name: "Twitter", url: "https://x.com/bangpateng_/", emoji: "&#128038;" },
      { name: "Telegram Channel", url: "https://t.me/bangpateng_airdrop/", emoji: "&#128172;" },
      { name: "Telegram Group", url: "https://t.me/bangPateng_chat/", emoji: "&#128483;" },
      { name: "Website Official", url: "https://bangpateng.xyz/", emoji: "&#127758;" }
    ]
  };
}

// Inisialisasi file dengan struktur kosong berdasarkan config
function initializeJsonFile() {
  const categoriesConfig = loadCategoriesConfig();
  const emptyStructure = {};
  
  // Buat struktur kosong berdasarkan kategori dari config
  Object.keys(categoriesConfig).forEach(categoryName => {
    emptyStructure[categoryName] = [];
  });
  
  try {
    if (!fs.existsSync(POSTS_FILE)) {
      fs.writeFileSync(POSTS_FILE, JSON.stringify(emptyStructure, null, 2));
      logMessage('File JSON dibuat dengan struktur kosong berdasarkan config');
    } else {
      try {
        // Coba parse untuk memastikan JSON valid
        const existingData = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
        
        // Update struktur jika ada kategori baru di config
        let needUpdate = false;
        Object.keys(categoriesConfig).forEach(categoryName => {
          if (!existingData[categoryName]) {
            existingData[categoryName] = [];
            needUpdate = true;
          }
        });
        
        if (needUpdate) {
          fs.writeFileSync(POSTS_FILE, JSON.stringify(existingData, null, 2));
          logMessage('File JSON diupdate dengan kategori baru dari config');
        }
      } catch (error) {
        // Jika JSON tidak valid, tulis ulang file
        logMessage('File JSON tidak valid, menulis ulang berdasarkan config');
        fs.writeFileSync(POSTS_FILE, JSON.stringify(emptyStructure, null, 2));
      }
    }
  } catch (error) {
    logMessage(`Error saat inisialisasi file: ${error.message}`);
  }
  
  return emptyStructure;
}

// Reset file JSON ke struktur kosong berdasarkan config
function resetJsonFile() {
  const categoriesConfig = loadCategoriesConfig();
  const emptyStructure = {};
  
  Object.keys(categoriesConfig).forEach(categoryName => {
    emptyStructure[categoryName] = [];
  });
  
  try {
    fs.writeFileSync(POSTS_FILE, JSON.stringify(emptyStructure, null, 2));
    logMessage('File JSON telah direset ke struktur kosong berdasarkan config');
    return true;
  } catch (error) {
    logMessage(`Error saat reset file: ${error.message}`);
    return false;
  }
}

// Fungsi untuk membersihkan duplikasi
function cleanDuplicates() {
  try {
    logMessage('Membersihkan duplikasi data...');
    
    // Baca file JSON
    let categories = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
    let cleaned = false;
    
    // Bersihkan duplikasi di setiap kategori
    Object.keys(categories).forEach(categoryName => {
      if (categories[categoryName] && categories[categoryName].length > 0) {
        const originalLength = categories[categoryName].length;
        
        // Gunakan Set untuk menghapus duplikasi berdasarkan URL
        const uniqueEntries = [];
        const seenUrls = new Set();
        
        categories[categoryName].forEach(entry => {
          // Extract URL dari entry
          const urlMatch = entry.match(/href="([^"]+)"/);
          if (urlMatch) {
            const url = urlMatch[1];
            if (!seenUrls.has(url)) {
              seenUrls.add(url);
              uniqueEntries.push(entry);
            }
          } else {
            // Jika tidak ada URL, tetap simpan (safety)
            uniqueEntries.push(entry);
          }
        });
        
        categories[categoryName] = uniqueEntries;
        
        if (originalLength !== uniqueEntries.length) {
          logMessage(`${categoryName}: ${originalLength} ? ${uniqueEntries.length} (${originalLength - uniqueEntries.length} duplikasi dihapus)`);
          cleaned = true;
        }
      }
    });
    
    if (cleaned) {
      // Simpan file yang sudah dibersihkan
      fs.writeFileSync(POSTS_FILE, JSON.stringify(categories, null, 2));
      logMessage('Data duplikasi berhasil dibersihkan');
    } else {
      logMessage('Tidak ada duplikasi yang ditemukan');
    }
    
    return cleaned;
  } catch (error) {
    logMessage(`Error saat membersihkan duplikasi: ${error.message}`);
    return false;
  }
}

// Fungsi untuk handle URL dengan underscore
function handleUnderscoreUrl(url) {
  // Encode underscore untuk URL yang aman untuk HTML Telegram
  return url.replace(/_/g, '%5F');
}

// Verifikasi format HTML untuk memastikan semua tag ditutup
function sanitizeHtml(text) {
  logMessage("Sanitizing HTML...");
  
  // Escape underscore dalam URL terlebih dahulu untuk mencegah masalah formatting
  let sanitized = text.replace(/<a\s+href="([^"]*_[^"]*)">/g, (match, url) => {
    const escapedUrl = handleUnderscoreUrl(url);
    return `<a href="${escapedUrl}">`;
  });
  
  // Mengganti semua tag dengan placeholder aman
  sanitized = sanitized
    .replace(/<a\s+href="([^"]+)">/g, "LINKSTART_$1_")
    .replace(/<\/a>/g, "_LINKEND")
    .replace(/<b>/g, "BOLDSTART")
    .replace(/<\/b>/g, "BOLDEND")
    .replace(/<i>/g, "ITALICSTART")
    .replace(/<\/i>/g, "ITALICEND");
    
  // Mengganti kembali dengan tag yang benar
  sanitized = sanitized
    .replace(/LINKSTART_([^_]+)_/g, `<a href="$1">`)
    .replace(/_LINKEND/g, "</a>")
    .replace(/BOLDSTART/g, "<b>")
    .replace(/BOLDEND/g, "</b>")
    .replace(/ITALICSTART/g, "<i>")
    .replace(/ITALICEND/g, "</i>");
  
  // Memastikan semua tag ditutup
  const openTags = (sanitized.match(/<[^\/][^>]*>/g) || []).length;
  const closeTags = (sanitized.match(/<\/[^>]*>/g) || []).length;
  
  logMessage(`Tags check: ${openTags} open tags, ${closeTags} close tags`);
  
  if (openTags > closeTags) {
    logMessage("Unclosed tags detected, adding missing closing tags");
    // Menambahkan tag penutup untuk tag yang tidak ditutup
    const diff = openTags - closeTags;
    for (let i = 0; i < diff; i++) {
      if (sanitized.lastIndexOf('<a') > sanitized.lastIndexOf('</a>')) {
        sanitized += '</a>';
      } else if (sanitized.lastIndexOf('<b') > sanitized.lastIndexOf('</b>')) {
        sanitized += '</b>';
      } else if (sanitized.lastIndexOf('<i') > sanitized.lastIndexOf('</i>')) {
        sanitized += '</i>';
      }
    }
  }
  
  return sanitized;
}

// Middleware
app.use(express.json());

// Webhook endpoint
app.post('/webhook', async (req, res) => {
  try {
    const update = req.body;
    if (update.channel_post && update.channel_post.chat.id.toString() === CHANNEL_ID) {
      const currentTime = moment().tz("Asia/Jakarta");
      const hour = currentTime.hour();
      const minute = currentTime.minute();
      
      // Hanya proses pesan antara 00:03 - 23:55
      if ((hour === 0 && minute >= 3) || (hour === 23 && minute <= 55) || (hour > 0 && hour < 23)) {
        logMessage(`Menerima pesan pada ${hour}:${minute} WIB`);
        await processMessage(update.channel_post);
      }
    }
    res.sendStatus(200);
  } catch (error) {
    logMessage(`Error webhook: ${error.message}`);
    res.sendStatus(500);
  }
});

// Test endpoint untuk recap manual
app.get('/test-recap', async (req, res) => {
  try {
    logMessage('Menjalankan recap manual');
    await sendRecap();
    res.send('Recap sent successfully');
  } catch (error) {
    logMessage(`Error recap manual: ${error.message}`);
    res.status(500).send(`Error: ${error.message}`);
  }
});

// Endpoint untuk clean duplikasi
app.get('/clean-duplicates', async (req, res) => {
  try {
    logMessage('Menjalankan clean duplicates manual');
    const cleaned = cleanDuplicates();
    if (cleaned) {
      res.send('Duplicates cleaned successfully');
    } else {
      res.send('No duplicates found');
    }
  } catch (error) {
    logMessage(`Error clean duplicates manual: ${error.message}`);
    res.status(500).send(`Error: ${error.message}`);
  }
});

// FUNGSI PROCESSEDMESSAGE YANG SUDAH DIPERBAIKI (MENGGUNAKAN SISTEM PRIORITAS)
async function processMessage(message) {
  try {
    const text = message.text || message.caption || '';
    const messageId = message.message_id;
    const link = `https://t.me/c/${CHANNEL_ID.replace('-100', '')}/${messageId}`;
    const name = text.split("\n")[0].slice(0, 50);

    logMessage(`Memproses pesan: ${name}`);

    // Load config categories
    const categoriesConfig = loadCategoriesConfig();

    // Baca file JSON
    let categories;
    try {
      categories = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
    } catch (error) {
      logMessage(`Error membaca file, membuat baru: ${error.message}`);
      categories = initializeJsonFile();
    }

    // SISTEM PRIORITAS: Urutan kategori berdasarkan prioritas (yang lebih spesifik duluan)
    const categoryPriority = [
      "Garapan Landing",        // Prioritas 1 (paling spesifik - cair, jp)
      "Garapan Node",          // Prioritas 2 (node, validator)
      "Garapan Testnet",       // Prioritas 3 (testnet)
      "Garapan Whitelist",     // Prioritas 4 (whitelist, WL)
      "Garapan Airdrop Bot and Gleam", // Prioritas 5 (airdrop, bot, gleam)
      "Garapan Update"         // Prioritas 6 (paling umum - update, news, info)
    ];

    let saved = false;
    let savedToCategory = null;
    const newEntry = `<a href="${link}">${name.replace(/\?\?/g, '')}</a>`;
    
    // Cek berdasarkan PRIORITAS (yang pertama match akan dipilih)
    for (const categoryName of categoryPriority) {
      if (!categoriesConfig[categoryName]) continue;
      
      const categoryConfig = categoriesConfig[categoryName];
      let categoryMatches = false;
      let matchedHashtag = '';
      
      // Cek apakah ada hashtag yang cocok di kategori ini
      for (const hashtag of categoryConfig.hashtags) {
        const escapedHashtag = hashtag.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(escapedHashtag, 'i');
        
        if (text.match(regex)) {
          categoryMatches = true;
          matchedHashtag = hashtag;
          break;
        }
      }
      
      // Jika match, simpan di kategori ini dan STOP (tidak cek kategori lain)
      if (categoryMatches) {
        if (!categories[categoryName]) {
          categories[categoryName] = [];
        }
        
        // Cek duplikasi berdasarkan message ID
        const isDuplicate = categories[categoryName].some(item => 
          item.includes(`/${messageId}`)
        );
        
        if (!isDuplicate) {
          categories[categoryName].push(newEntry);
          saved = true;
          savedToCategory = categoryName;
          logMessage(`Ditambahkan ke kategori (prioritas): ${categoryName} - hashtag: ${matchedHashtag}`);
        } else {
          logMessage(`Duplikasi terdeteksi untuk: ${categoryName}`);
        }
        
        break; // PENTING: Stop di kategori pertama yang match!
      }
    }

    if (saved) {
      fs.writeFileSync(POSTS_FILE, JSON.stringify(categories, null, 2));
      logMessage(`Pesan berhasil disimpan ke: ${savedToCategory}`);
    } else {
      logMessage('Tidak ada hashtag yang cocok atau sudah ada duplikasi');
    }
  } catch (error) {
    logMessage(`Error memproses pesan: ${error.message}`);
    throw error;
  }
}

// Mengirim recap berdasarkan config
async function sendRecap() {
  try {
    logMessage('Memulai proses recap...');
    
    // Load configs
    const categoriesConfig = loadCategoriesConfig();
    const socialMediaConfig = loadSocialMediaConfig();
    
    // Baca file JSON
    let categories;
    try {
      categories = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
      logMessage('Berhasil membaca file JSON');
    } catch (error) {
      logMessage(`Error membaca file JSON: ${error.message}`);
      return;
    }
    
    // Cek apakah ada content untuk di-recap
    let hasContent = false;
    Object.keys(categories).forEach(section => {
      if (categories[section] && categories[section].length > 0) {
        hasContent = true;
      }
    });
    
    if (!hasContent) {
      logMessage('Tidak ada content untuk di-recap, proses dibatalkan');
      return;
    }
    
    // Buat pesan recap
    const today = moment().format("DD MMM YYYY");
    let summary = `&#128209; <b>Recap Garapan Tanggal ${today} Kalo Ada Yang Kesekip Gawein Bang Segera! DONT Tar Sok Tar Sok... </b>\n`;

    // Tambahkan konten per kategori berdasarkan config (dengan urutan prioritas)
    const categoryOrder = [
      "Garapan Testnet",
      "Garapan Whitelist", 
      "Garapan Airdrop Bot and Gleam",
      "Garapan Node",
      "Garapan Update",
      "Garapan Landing"
    ];

    categoryOrder.forEach(section => {
      if (categoriesConfig[section] && categories[section] && categories[section].length > 0) {
        const sectionEmoji = categoriesConfig[section].emoji;

        summary += `\n${sectionEmoji} <b>${section}</b>\n\n`;
        
        // Tidak perlu membatasi entri untuk relay channel
        categories[section].forEach(item => {
          summary += `&#9642; ${item}\n`;
        });
      }
    });

    // Tambahkan social media berdasarkan config
    summary += `\n${socialMediaConfig.titleEmoji} <b>${socialMediaConfig.title}</b>\n\n`;
    
    socialMediaConfig.links.forEach(link => {
      // Handle URL yang mengandung underscore
      let safeUrl = link.url;
      if (link.url.includes('_')) {
        safeUrl = handleUnderscoreUrl(link.url);
      }
      summary += `${link.emoji} <a href="${safeUrl}"><b>${link.name}</b></a>\n`;
    });
    
    // Sanitize HTML
    summary = sanitizeHtml(summary);
    
    try {
      // LANGKAH 1: Kirim gambar ke relay channel
      const imagePath = "./img/recapgarapan.png";
      if (fs.existsSync(imagePath)) {
        logMessage('Mengirim gambar ke relay channel...');
        const formData = new FormData();
        formData.append("chat_id", RELAY_CHANNEL_ID);
        formData.append("photo", fs.createReadStream(imagePath));
        
        await axios.post(`${TELEGRAM_API}/sendPhoto`, formData, {
          headers: formData.getHeaders(),
          timeout: 30000
        });
        logMessage('Gambar berhasil dikirim ke relay channel');
        
        // Tunggu sebentar
        await new Promise(resolve => setTimeout(resolve, 1000));
      } else {
        logMessage('Gambar tidak ditemukan, melanjutkan tanpa gambar');
      }
      
      // LANGKAH 2: Kirim teks lengkap ke relay channel
      logMessage('Mengirim teks recap lengkap ke relay channel...');
      const relayResponse = await axios.post(`${TELEGRAM_API}/sendMessage`, {
        chat_id: RELAY_CHANNEL_ID,
        text: summary,
        parse_mode: "HTML",
        disable_web_page_preview: true
      });
      
      if (relayResponse.data && relayResponse.data.ok) {
        logMessage('Recap teks lengkap berhasil dikirim ke relay channel');
        
        
        // Reset categories
        resetJsonFile();
        logMessage('File JSON telah direset setelah mengirim recap');
      } else {
        logMessage(`Gagal mengirim ke relay channel: ${JSON.stringify(relayResponse.data)}`);
        
        // Reset categories
        resetJsonFile();
      }
    } catch (error) {
      logMessage(`Error mengirim recap: ${error.message}`);
      if (error.response) {
        logMessage(`Response error: ${JSON.stringify(error.response.data)}`);
        
        // Jika error parsing HTML, coba kirim tanpa HTML
        if (error.response.data && error.response.data.description && 
            error.response.data.description.includes("can't parse entities")) {
          logMessage("HTML parsing error detected, trying without HTML formatting...");
          
          // Buat versi plain text
          let plainText = "RECAP GARAPAN " + today + "\n\n";
          
          categoryOrder.forEach(section => {
            if (categoriesConfig[section] && categories[section] && categories[section].length > 0) {
              plainText += `### ${section} ###\n\n`;
              categories[section].forEach(item => {
                // Strip HTML tags
                const plainItem = item.replace(/<[^>]*>/g, '');
                plainText += `- ${plainItem}\n`;
              });
              plainText += "\n";
            }
          });
          
          plainText += "OFFICIAL MEDIA:\n";
          socialMediaConfig.links.forEach(link => {
            plainText += `${link.name}: ${link.url}\n`;
          });
          
          try {
            // Coba kirim plain text ke relay channel
            await axios.post(`${TELEGRAM_API}/sendMessage`, {
              chat_id: RELAY_CHANNEL_ID,
              text: plainText,
              disable_web_page_preview: true
            });
            logMessage("Plain text recap sent to relay channel");
            
            // Reset JSON file
            resetJsonFile();
          } catch (fallbackError) {
            logMessage(`Fallback also failed: ${fallbackError.message}`);
          }
        }
      }
    }
  } catch (error) {
    logMessage(`Fatal error dalam sendRecap: ${error.message}`);
    throw error;
  }
}

// Setup webhook
async function setupWebhook() {
  try {
    const webhookUrl = `${WEBHOOK_URL}/webhook`;
    logMessage(`Setting up webhook at: ${webhookUrl}`);
    
    const response = await axios.post(`${TELEGRAM_API}/setWebhook`, {
      url: webhookUrl,
      allowed_updates: ["channel_post"]
    });
    
    if (response.data && response.data.ok) {
      logMessage('Webhook berhasil di-setup');
      return true;
    } else {
      logMessage(`Gagal setup webhook: ${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    logMessage(`Error setup webhook: ${error.message}`);
    return false;
  }
}

// Main function
async function main() {
  try {
    // Pastikan file log ada
    if (!fs.existsSync(LOG_FILE)) {
      fs.writeFileSync(LOG_FILE, '', 'utf8');
    }
    
    logMessage('=== Bot Starting ===');
    logMessage(`Menggunakan channel relay ID: ${RELAY_CHANNEL_ID}`);
    
    // Initialize config files jika belum ada
    if (!fs.existsSync(CATEGORIES_CONFIG_FILE)) {
      logMessage('Creating default categories config file...');
      // File akan dibuat otomatis saat loadCategoriesConfig() dipanggil
    }
    
    if (!fs.existsSync(SOCIAL_MEDIA_CONFIG_FILE)) {
      logMessage('Creating default social media config file...');
      // File akan dibuat otomatis saat loadSocialMediaConfig() dipanggil
    }
    
    // Initialize JSON file berdasarkan config
    initializeJsonFile();
    
    // Setup webhook
    await setupWebhook();
    
    // Interval check untuk recap dan maintenance
    setInterval(async () => {
      const now = moment().tz("Asia/Jakarta");
      const hour = now.hour();
      const minute = now.minute();
      
      // Log setiap 5 menit untuk memastikan bot masih hidup
      if (minute % 5 === 0) {
        logMessage(`Current time check: ${hour}:${minute} WIB`);
      }
      
      // Kirim recap pada jam 23:58
      if (hour === 23 && minute === 58) {
        logMessage('Waktunya recap! Memulai proses recap...');
        try {
          await sendRecap();
        } catch (error) {
          logMessage(`Error menjalankan recap: ${error.message}`);
          
          // Coba lagi setelah 30 detik jika gagal
          setTimeout(async () => {
            logMessage('Mencoba ulang recap...');
            try {
              await sendRecap();
            } catch (retryError) {
              logMessage(`Gagal retry recap: ${retryError.message}`);
            }
          }, 30000);
        }
      }
      
      // Verifikasi file JSON setiap jam
      if (minute === 0) {
        try {
          JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
          logMessage('File JSON valid');
        } catch (error) {
          logMessage(`File JSON tidak valid, menginisialisasi ulang: ${error.message}`);
          initializeJsonFile();
        }
      }
      
      // Reset file di tengah malam jika belum tereset oleh recap
      if (hour === 0 && minute === 1) {
        logMessage('Pengecekan reset tengah malam');
        try {
          const categories = JSON.parse(fs.readFileSync(POSTS_FILE, 'utf8'));
          let hasContent = false;
          
          Object.keys(categories).forEach(section => {
            if (categories[section] && categories[section].length > 0) {
              hasContent = true;
            }
          });
          
          if (hasContent) {
            logMessage('File masih memiliki content, melakukan reset...');
            resetJsonFile();
          }
        } catch (error) {
          logMessage(`Error pengecekan tengah malam: ${error.message}`);
          initializeJsonFile();
        }
      }
    }, 60000); // Check setiap menit
    
    // Start server
    app.listen(PORT, () => {
      logMessage(`Server berjalan di port ${PORT}`);
    });
  } catch (error) {
    logMessage(`Fatal error: ${error.message}`);
  }
}

// Start application
main();