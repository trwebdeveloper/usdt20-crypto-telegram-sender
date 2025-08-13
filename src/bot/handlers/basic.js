const logger = require('../../utils/logger');
const db = require('../../database');

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

        await ctx.reply(`🎉 Hoş geldiniz ${ctx.from.first_name}!

🤖 **Crypto Bot'a Hoş Geldiniz**

💰 Bu bot ile USDT (TRC20) gönderimi yapabilirsiniz.

🔹 **Ana Komutlar:**
/help - Yardım menüsü
/addwallet - Cüzdan ekle
/wallets - Cüzdanları listele
/balance - Bakiye sorgula
/send - USDT gönder

🚀 Başlamak için /addwallet ile cüzdan ekleyin!`, { parse_mode: 'Markdown' });

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
