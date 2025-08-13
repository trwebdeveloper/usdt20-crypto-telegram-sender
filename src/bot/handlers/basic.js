const logger = require('../../utils/logger');
const db = require('../../database');

// Basit bir welcome image generator (SVG to base64)
function createWelcomeImage() {
  const svg = `
    <svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style="stop-color:#667eea;stop-opacity:1" />
          <stop offset="100%" style="stop-color:#764ba2;stop-opacity:1" />
        </linearGradient>
      </defs>
      <rect width="400" height="200" fill="url(#bg)"/>
      <text x="200" y="80" font-family="Arial, sans-serif" font-size="36" font-weight="bold" fill="white" text-anchor="middle">CRYPTO BOT</text>
      <text x="200" y="120" font-family="Arial, sans-serif" font-size="18" fill="white" text-anchor="middle">TRC20 Wallet Manager</text>
      <circle cx="200" cy="160" r="15" fill="none" stroke="white" stroke-width="2"/>
      <path d="M200 150 L200 170 M190 160 L210 160" stroke="white" stroke-width="2"/>
    </svg>
  `;
  return Buffer.from(svg).toString('base64');
}

class BasicHandlers {
  static start() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const username = ctx.from.username || '';
        
        logger.info(`Yeni kullanıcı: ${ctx.from.first_name} (${telegramId})`);
        
        // Kullanıcıyı veritabanında oluştur veya güncelle
        let user = await db.get('SELECT * FROM users WHERE telegram_id = ?', [telegramId]);
        
        if (!user) {
          await db.run(
            'INSERT INTO users (telegram_id, username, created_at) VALUES (?, ?, ?)',
            [telegramId, username, new Date().toISOString()]
          );
        }

        const welcomeMessage = `
🎉 **HOŞ GELDİNİZ ${ctx.from.first_name}!** 🎉

╔═══════════════════════════════╗
║     🤖 CRYPTO WALLET BOT 🤖      ║
╚═══════════════════════════════╝

📊 **Güvenli TRC20 Cüzdan Yönetimi**
🔐 256-bit AES Şifreleme
⚡ Hızlı TRON Ağı İşlemleri
💎 USDT & TRX Desteği

━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀 **HIZLI BAŞLANGIÇ**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣ Cüzdan Ekle → /addwallet
2️⃣ Bakiye Kontrol → /balance  
3️⃣ Transfer Yap → /send

💡 Detaylı bilgi için /help yazın
        `;

        // Ana menü butonları
        const keyboard = {
          inline_keyboard: [
            [
              { text: '💼 Cüzdan Ekle', callback_data: 'add_wallet' },
              { text: '💰 Bakiye Kontrol', callback_data: 'check_balance' }
            ],
            [
              { text: '📤 Transfer Yap', callback_data: 'send_crypto' },
              { text: '📊 İşlem Geçmişi', callback_data: 'history' }
            ],
            [
              { text: '📖 Yardım', callback_data: 'help' },
              { text: '⚙️ Ayarlar', callback_data: 'settings' }
            ]
          ]
        };

        await ctx.replyWithPhoto(
          { source: Buffer.from(createWelcomeImage(), 'base64') },
          {
            caption: welcomeMessage,
            parse_mode: 'Markdown',
            reply_markup: keyboard
          }
        ).catch(async () => {
          // Eğer görsel gönderilemezse sadece mesaj gönder
          await ctx.reply(welcomeMessage, { 
            parse_mode: 'Markdown',
            reply_markup: keyboard
          });
        });

      } catch (error) {
        logger.error('Start komutu hatası:', error.message);
        await ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    };
  }

  static help() {
    return async (ctx) => {
      const helpText = `🔹 **Crypto Bot Komutları**

**💰 Cüzdan İşlemleri:**
/addwallet - Yeni cüzdan ekle
/wallets - Cüzdanları listele
/balance - Bakiyeleri kontrol et

**📤 Transfer İşlemleri:**
/send [adres] [miktar] - USDT gönder
/multisend - Toplu USDT gönder

**🔧 Diğer Komutlar:**
/start - Bot'u yeniden başlat
/help - Bu yardım menüsü
/ping - Bağlantı testi

**📝 Örnek Kullanım:**
\`/send TK36L4ssjceA4qSmwVsFaysEnXbMkTcGgC 100\`

⚠️ **Güvenlik:** Private key'leriniz şifreli saklanır!`;

      await ctx.reply(helpText, { parse_mode: 'Markdown' });
    };
  }

  static ping() {
    return async (ctx) => {
      const startTime = Date.now();
      await ctx.reply('🏓 Pong!').then(() => {
        const endTime = Date.now();
        const responseTime = endTime - startTime;
        logger.info(`Ping response time: ${responseTime}ms`);
      });
    };
  }
}

module.exports = BasicHandlers;
