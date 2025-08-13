const { Markup } = require('telegraf');
const db = require('../../database');
const logger = require('../../utils/logger');

class HistoryHandlers {
  static transactionHistory() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        
        const transactions = await db.all(`
          SELECT t.*, w.name as wallet_name 
          FROM transactions t
          JOIN wallets w ON t.from_wallet = w.address
          JOIN users u ON w.user_id = u.id
          WHERE u.telegram_id = ? 
          ORDER BY t.created_at DESC 
          LIMIT 20
        `, [telegramId]);

        if (!transactions || transactions.length === 0) {
          await ctx.reply('📭 **Henüz hiç işlem yapmadınız.**\n\n💡 İlk transferinizi yapmak için /send komutunu kullanın.');
          return;
        }

        let message = `📊 **İşlem Geçmişi** (Son ${transactions.length})\n\n`;

        transactions.forEach((tx, index) => {
          const date = new Date(tx.created_at).toLocaleString('tr-TR');
          const status = this.getStatusEmoji(tx.status);
          const shortHash = tx.tx_hash.substring(0, 8) + '...';
          const shortTo = tx.to_address.substring(0, 8) + '...';

          message += `**${index + 1}.** ${status} ${tx.amount} USDT\n`;
          message += `   📥 Alıcı: \`${shortTo}\`\n`;
          message += `   📅 ${date}\n`;
          message += `   🔗 \`${shortHash}\`\n\n`;
        });

        message += `🔍 **Detay için:** Hash'e tıklayıp TronScan'de görüntüleyebilirsiniz.`;

        const keyboard = Markup.inlineKeyboard([
          [
            Markup.button.callback('📊 Başarılı İşlemler', 'history_success'),
            Markup.button.callback('❌ Başarısız İşlemler', 'history_failed')
          ],
          [
            Markup.button.callback('📈 Bu Hafta', 'history_week'),
            Markup.button.callback('📅 Bu Ay', 'history_month')
          ],
          [Markup.button.callback('🔄 Yenile', 'history_refresh')]
        ]);

        await ctx.reply(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard
        });

      } catch (error) {
        logger.error('Transaction history error:', error);
        await ctx.reply('❌ İşlem geçmişi yüklenemedi.');
      }
    };
  }

  static getStatusEmoji(status) {
    switch (status) {
      case 'confirmed': return '✅';
      case 'failed': return '❌';
      case 'pending': return '⏳';
      case 'broadcast': return '📡';
      default: return '❓';
    }
  }
}

module.exports = HistoryHandlers;
