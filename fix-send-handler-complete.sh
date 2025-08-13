#!/bin/bash
echo "🔧 Send handler tamamen yeniden yazılıyor..."

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
        
        if (!tronService.isValidAddress(address)) {
          await ctx.reply('❌ Geçersiz TRON adresi!\n\nLütfen geçerli bir TRC20 adres girin:');
          return;
        }

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
        
        if (isNaN(amount) || amount <= 0) {
          await ctx.reply('❌ Geçersiz miktar!\n\nLütfen pozitif bir sayı girin (örnek: 100):');
          return;
        }

        if (amount > 10000) {
          await ctx.reply('❌ Miktar çok yüksek!\n\nEn fazla 10,000 USDT gönderebilirsiniz:');
          return;
        }

        ctx.session.sendAmount = amount;
        ctx.session.waitingFor = 'send_password';

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

  // Confirmation callback fonksiyonu
  static createConfirmationCallback(ctx) {
    return async (telegramId, confirmationData) => {
      try {
        logger.info(`🔍 Confirmation callback received:`, {
          telegramId,
          success: confirmationData.success,
          txHash: confirmationData.txHash
        });

        let message = '';
        
        if (confirmationData.success === true) {
          // ✅ Başarılı işlem
          message = `✅ **İşlem Başarıyla Tamamlandı!**

🔗 **Transaction Hash:**
\`${confirmationData.txHash}\`

📊 **İşlem Detayları:**
💰 Miktar: ${confirmationData.amount} USDT
📤 Gönderen: \`${confirmationData.fromAddress.substring(0, 8)}...\`
📥 Alıcı: \`${confirmationData.toAddress.substring(0, 8)}...\`
📅 Zaman: ${new Date().toLocaleString('tr-TR')}

💸 **Blockchain Bilgileri:**
⛽ Ödenen Fee: ${confirmationData.fee || 0} TRX
⚡ Energy: ${confirmationData.energyUsed || 0}
📦 Block: ${confirmationData.blockNumber || 'N/A'}
✅ Durum: ${confirmationData.result || 'SUCCESS'}

🔍 **TronScan:**
https://tronscan.org/#/transaction/${confirmationData.txHash}

🎉 **USDT başarıyla gönderildi!**`;

        } else if (confirmationData.success === false) {
          // ❌ Başarısız işlem
          message = `❌ **İşlem Başarısız!**

🔗 **Transaction Hash:**
\`${confirmationData.txHash}\`

📊 **Detaylar:**
💰 Miktar: ${confirmationData.amount} USDT
❌ Durum: ${confirmationData.result || 'FAILED'}
⛽ Fee: ${confirmationData.fee || 0} TRX

🔍 **TronScan:**
https://tronscan.org/#/transaction/${confirmationData.txHash}

💡 **USDT gönderilmedi.**`;

        } else {
          // Diğer durumlar - mesaj gönderme
          logger.info(`Mesaj gönderilmedi - belirsiz durum:`, confirmationData);
          return;
        }

        // Mesajı gönder
        await ctx.telegram.sendMessage(telegramId, message, { parse_mode: 'Markdown' });
        
        logger.info(`Confirmation mesajı gönderildi: ${telegramId}`);

      } catch (error) {
        logger.error('Confirmation callback hatası:', error);
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

        const loadingMsg = await ctx.reply('🔄 İşlem blockchain\'e gönderiliyor...\n\n⏳ Lütfen bekleyin...');

        const telegramId = ctx.from.id;
        const walletId = ctx.session.sendWalletId;
        const toAddress = ctx.session.sendToAddress;
        const amount = ctx.session.sendAmount;

        // Confirmation callback'i oluştur
        const confirmationCallback = SendHandlers.createConfirmationCallback(ctx);

        // Transfer yap
        const result = await walletService.sendUsdt(telegramId, walletId, toAddress, amount, masterPassword, confirmationCallback);

        // Session'ı temizle
        delete ctx.session.sendWalletId;
        delete ctx.session.sendToAddress;
        delete ctx.session.sendAmount;
        delete ctx.session.waitingFor;

        // İlk hash mesajı (basit)
        const initialMessage = `📤 **İşlem Blockchain'e Gönderildi!**

🔗 **Transaction Hash:**
\`${result.txHash}\`

⏳ Confirmation bekleniyor...`;

        await ctx.telegram.editMessageText(
          ctx.chat.id,
          loadingMsg.message_id,
          null,
          initialMessage,
          { parse_mode: 'Markdown' }
        );

        logger.info(`USDT transfer başlatıldı: ${amount} USDT - User: ${telegramId} - TX: ${result.txHash}`);

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

echo "✅ Send handler tamamen yeniden yazıldı!"
