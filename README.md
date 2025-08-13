# 📤 USDT TRC20 Crypto Telegram Sender

Telegram üzerinden güvenli USDT (TRC20) transferi yapabilen bot sistemi.

## ✨ Özellikler

### 💰 Cüzdan Yönetimi
- 🔐 Güvenli cüzdan ekleme (AES-256 şifreleme)
- 💼 Çoklu cüzdan desteği
- 💰 Anlık bakiye sorgulama (TRX + USDT)
- 📱 Kullanıcı dostu arayüz

### 📤 Transfer İşlemleri
- 🚀 **Basit gönderim:** `/send adres miktar`
- 📊 **Toplu gönderim:** `/multisend` (max 50 işlem)
- ⚡ Gerçek zamanlı confirmation takibi
- 🔄 Otomatik retry sistemi

### 📊 Raporlama
- 📄 Otomatik multisend raporları
- 📈 İşlem geçmişi görüntüleme
- 📱 Filtreleme seçenekleri
- 💾 Exportable raporlar

### 🛡️ Güvenlik
- 🔒 AES-256-GCM şifreleme
- 🔑 Master şifre sistemi
- ⏰ Rate limiting
- 🚫 Maksimum transfer limitleri

## 🚀 Kurulum

### Gereksinimler
- Node.js 18+
- SQLite3
- TRON API Key (ücretsiz)

### Adımlar

1. **Repository'i klonlayın:**
```bash
git clone https://github.com/trwebdeveloper/usdt20-crypto-telegram-sender.git
cd usdt20-crypto-telegram-sender
