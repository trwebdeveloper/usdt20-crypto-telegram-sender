#!/bin/bash
echo "🔧 USDT gönderme işlemi tamamlanıyor..."

# Send handlers'ı güncelle
cat > src/bot/handlers/send.js << 'SENDEOF'
const walletService = require('../../blockchain/wallet');
const tronService = require('../../blockchain/tron');
const logger = require('../../utils/logger');
const { Markup } = require('telegraf');

class SendHandlers {

  static sendMenu() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);

        if (wallets.length === 0) {
          await ctx.reply('📭 USDT göndermek için önce cüzdan eklemelisiniz.\n\n➕ /addwallet komutu ile cüzdan ekleyin.');
          return;
        }

        let message = `💸 *USDT Gönderme*\n\n`;
        message += `Hangi cüzdandan göndermek istiyorsunuz?\n\n`;

        const buttons = wallets.map((wallet, index) => {
          const shortAddress = `${wallet.address.substring(0, 6)}...${wallet.address.substring(-4)}`;
          return [Markup.button.callback(`${index + 1}. ${wallet.name} (${shortAddress})`, `send_from_${wallet.id}`)];
        });

        buttons.push([Markup.button.callback('❌ İptal', 'send_cancel')]);

        const keyboard = Markup.inlineKeyboard(buttons);

        await ctx.reply(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard.reply_markup
        });

      } catch (error) {
        logger.error('Send menu hatası:', error);
        await ctx.reply('❌ Gönderme menüsü yüklenemedi.');
      }
    };
  }

  static selectWallet() {
    return async (ctx) => {
      try {
        const walletId = ctx.match[1];
        
        // Session'a wallet ID'yi kaydet
        ctx.session.sendWalletId = walletId;
        ctx.session.waitingFor = 'send_address';
        
        await ctx.answerCbQuery();
        await ctx.reply('📝 Hedef adres girin:\n\n⚠️ TRON (TRC20) adresini dikkatli girin!\n\n❌ İptal etmek için /cancel yazın');

      } catch (error) {
        logger.error('Select wallet hatası:', error);
        await ctx.answerCbQuery('❌ Hata oluştu');
      }
    };
  }

  static handleSendAddress() {
    return async (ctx) => {
      try {
        const address = ctx.message.text.trim();
        
        // Adres doğrula
        if (!tronService.isValidAddress(address)) {
          await ctx.reply('❌ Geçersiz TRON adresi!\n\nLütfen geçerli bir TRC20 adres girin:');
          return;
        }

        // Session'a adresi kaydet
        ctx.session.sendToAddress = address;
        ctx.session.waitingFor = 'send_amount';

        await ctx.reply('💰 Gönderilecek USDT miktarını girin:\n\n📌 Örnek: 100 veya 50.5\n\n❌ İptal etmek için /cancel yazın');

      } catch (error) {
        logger.error('Send address handle hatası:', error);
        await ctx.reply('❌ Adres işlenirken hata oluştu.');
      }
    };
  }

  static handleSendAmount() {
    return async (ctx) => {
      try {
        const amountStr = ctx.message.text.trim();
        const amount = parseFloat(amountStr);
        
        // Miktar doğrula
        if (isNaN(amount) || amount <= 0) {
          await ctx.reply('❌ Geçersiz miktar!\n\nLütfen pozitif bir sayı girin (örnek: 100):');
          return;
        }

        if (amount > 10000) {
          await ctx.reply('❌ Miktar çok yüksek!\n\nEn fazla 10,000 USDT gönderebilirsiniz:');
          return;
        }

        // Session'a miktarı kaydet
        ctx.session.sendAmount = amount;
        ctx.session.waitingFor = 'send_password';

        // Cüzdan bilgisini al ve onay göster
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);
        const wallet = wallets.find(w => w.id == ctx.session.sendWalletId);
        
        if (!wallet) {
          throw new Error('Cüzdan bulunamadı');
        }

        const shortFromAddress = `${wallet.address.substring(0, 6)}...${wallet.address.substring(-4)}`;
        const shortToAddress = `${ctx.session.sendToAddress.substring(0, 6)}...${ctx.session.sendToAddress.substring(-4)}`;

        const confirmMessage = `✅ *İşlem Onayı*

📤 *Gönderen:* ${wallet.name}
📍 \`${shortFromAddress}\`

📥 *Alıcı:*
📍 \`${shortToAddress}\`

💰 *Miktar:* ${amount} USDT
⛽ *Tahmini Fee:* ~20 TRX

🔐 İşlemi onaylamak için master şifrenizi girin:

❌ İptal etmek için /cancel yazın`;

        await ctx.reply(confirmMessage, { parse_mode: 'Markdown' });

      } catch (error) {
        logger.error('Send amount handle hatası:', error);
        await ctx.reply('❌ Miktar işlenirken hata oluştu.');
      }
    };
  }

  static handleSendPassword() {
    return async (ctx) => {
      try {
        const masterPassword = ctx.message.text.trim();
        
        if (masterPassword.length < 8) {
          await ctx.reply('❌ Şifre çok kısa!\n\nMaster şifrenizi girin:');
          return;
        }

        await ctx.reply('🔄 İşlem gerçekleştiriliyor, lütfen bekleyin...\n\n⏳ Bu işlem 30-60 saniye sürebilir.');

        const telegramId = ctx.from.id;
        const walletId = ctx.session.sendWalletId;
        const toAddress = ctx.session.sendToAddress;
        const amount = ctx.session.sendAmount;

        // Transfer yap
        const result = await walletService.sendUsdt(telegramId, walletId, toAddress, amount, masterPassword);

        // Session'ı temizle
        delete ctx.session.sendWalletId;
        delete ctx.session.sendToAddress;
        delete ctx.session.sendAmount;
        delete ctx.session.waitingFor;

        const successMessage = `✅ *İşlem Başarıyla Gönderildi!*

🔗 *Transaction Hash:*
\`${result.txHash}\`

📊 *Detaylar:*
💰 Miktar: ${amount} USDT
📤 Gönderen: \`${result.from.substring(0, 8)}...\`
📥 Alıcı: \`${toAddress.substring(0, 8)}...\`
📅 Zaman: ${new Date().toLocaleString('tr-TR')}

⏳ İşlem ağda onaylanıyor...
/status komutu ile durumu takip edebilirsiniz.

🎉 Başarılı transfer!`;

        await ctx.reply(successMessage, { parse_mode: 'Markdown' });

        logger.info(`USDT transfer başarılı: ${amount} USDT - User: ${telegramId} - TX: ${result.txHash}`);

      } catch (error) {
        logger.error('Send password handle hatası:', error);
        
        // Session'ı temizle
        delete ctx.session.sendWalletId;
        delete ctx.session.sendToAddress;
        delete ctx.session.sendAmount;
        delete ctx.session.waitingFor;

        let errorMessage = '❌ İşlem başarısız oldu.\n\n';
        
        if (error.message.includes('Yetersiz bakiye')) {
          errorMessage += '💰 Yetersiz bakiye.';
        } else if (error.message.includes('Geçersiz')) {
          errorMessage += '📍 Geçersiz adres.';
        } else if (error.message.includes('Şifre') || error.message.includes('decrypt')) {
          errorMessage += '🔐 Yanlış master şifre.';
        } else {
          errorMessage += `🔍 Hata: ${error.message}`;
        }

        await ctx.reply(errorMessage);
      }
    };
  }

  static cancelSend() {
    return async (ctx) => {
      try {
        // Session'ı temizle
        delete ctx.session.sendWalletId;
        delete ctx.session.sendToAddress;
        delete ctx.session.sendAmount;
        delete ctx.session.waitingFor;

        if (ctx.callbackQuery) {
          await ctx.answerCbQuery();
        }

        await ctx.reply('❌ USDT gönderme işlemi iptal edildi.');

      } catch (error) {
        logger.error('Cancel send hatası:', error);
      }
    };
  }
}

module.exports = SendHandlers;
SENDEOF

echo "✅ Send USDT işlemi tamamlandı!"
