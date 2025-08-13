const { Markup } = require('telegraf');
const pdfService = require("../../services/pdfService");
const walletService = require('../../services/walletService');
const logger = require('../../utils/logger');

class SendHandlers {
  static sendMenu() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);

        if (!wallets || wallets.length === 0) {
          await ctx.reply('❌ Hiç cüzdanınız yok!\n\n/addwallet komutu ile önce cüzdan ekleyin.');
          return;
        }

        const keyboard = wallets.map(wallet => [
          Markup.button.callback(
            `💰 ${wallet.name} (${wallet.address.substring(0, 8)}...)`,
            `send_from_${wallet.id}`
          )
        ]);

        keyboard.push([Markup.button.callback('❌ İptal', 'send_cancel')]);

        await ctx.reply(
          `📤 **USDT Gönder**\n\nGöndermek istediğiniz cüzdanı seçin:`,
          {
            parse_mode: 'Markdown',
            reply_markup: Markup.inlineKeyboard(keyboard)
          }
        );
      } catch (error) {
        logger.error('Send menu error:', error);
        await ctx.reply('❌ Bir hata oluştu!');
      }
    };
  }

  static createConfirmationCallback(ctx) {
    return async (telegramId, confirmationData) => {
      try {
        let message = '';

        if (confirmationData.success === true) {
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
⚡ Energy Kullanılan: ${confirmationData.energyUsed || 0}
📦 Block Numarası: ${confirmationData.blockNumber || 'N/A'}
✅ Durum: ${confirmationData.result || 'SUCCESS'}

🔍 **TronScan'de Görüntüle:**
https://tronscan.org/#/transaction/${confirmationData.txHash}

🎉 **USDT başarıyla gönderildi!**`;

        } else if (confirmationData.success === false) {
          message = `❌ **İşlem Başarısız Oldu!**

🔗 **Transaction Hash:**
\`${confirmationData.txHash}\`

📊 **İşlem Detayları:**
💰 Miktar: ${confirmationData.amount} USDT
📤 Gönderen: \`${confirmationData.fromAddress.substring(0, 8)}...\`
📥 Alıcı: \`${confirmationData.toAddress.substring(0, 8)}...\`
📅 Zaman: ${new Date().toLocaleString('tr-TR')}

❌ **Hata Bilgisi:**
🚫 Durum: ${confirmationData.result || 'FAILED'}
⛽ Harcanan Fee: ${confirmationData.fee || 0} TRX

🔍 **TronScan'de Görüntüle:**
https://tronscan.org/#/transaction/${confirmationData.txHash}

💡 **Not:** İşlem başarısız oldu, USDT gönderilmedi.`;

        } else {
          logger.info(`Confirmation callback - mesaj gönderilmedi:`, confirmationData);
          return;
        }

        await ctx.telegram.sendMessage(telegramId, message, { parse_mode: 'Markdown' });
        logger.info(`Confirmation mesajı gönderildi: ${telegramId}`);

      } catch (error) {
        logger.error('Confirmation callback hatası:', error);
      }
    };
  }

  // Basit Send: /send hedef_adres miktar
  static handleSimpleSend() {
    return async (ctx) => {
      try {
        const params = ctx.message.text.split(' ').slice(1);
        
        if (params.length !== 2) {
          await ctx.reply(`❌ **Yanlış format!**

🔸 **Doğru kullanım:**
\`/send [hedef_adres] [miktar]\`

**Örnek:**
\`/send TK36L4ssjceA4qSmwVsFaysEnXbMkTcGgC 100\``, { parse_mode: 'Markdown' });
          return;
        }

        const [toAddress, amount] = params;
        
        if (!toAddress.startsWith('T') || toAddress.length !== 34) {
          await ctx.reply('❌ Geçersiz TRON adresi!');
          return;
        }
        
        if (isNaN(amount) || parseFloat(amount) <= 0) {
          await ctx.reply('❌ Geçersiz miktar!');
          return;
        }

        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);
        
        if (!wallets || wallets.length === 0) {
          await ctx.reply('❌ Hiç cüzdanınız yok! Önce /addwallet ile cüzdan ekleyin.');
          return;
        }

        const activeWallet = wallets[0];

        await ctx.reply(`🔸 **İşlem Onayı**

💰 **Miktar:** ${amount} USDT
📤 **Gönderen:** \`${activeWallet.name}\` (\`${activeWallet.address.substring(0, 8)}...\`)
📥 **Hedef:** \`${toAddress.substring(0, 8)}...${toAddress.substring(26)}\`

⚠️ **Master şifrenizi girin:**`, { parse_mode: 'Markdown' });

        ctx.session.simpleWalletId = activeWallet.id;
        ctx.session.simpleAmount = parseFloat(amount);
        ctx.session.simpleToAddress = toAddress;
        ctx.session.waitingFor = 'simple_send_password';

      } catch (error) {
        logger.error('Simple send error:', error);
        await ctx.reply('❌ İşlem başarısız!');
      }
    };
  }

  static handleSimpleSendPassword() {
    return async (ctx) => {
      try {
        const masterPassword = ctx.message.text.trim();
        
        if (masterPassword.length < 8) {
          await ctx.reply('❌ Şifre çok kısa! Master şifrenizi girin:');
          return;
        }

        const telegramId = ctx.from.id;
        const walletId = ctx.session.simpleWalletId;
        const amount = ctx.session.simpleAmount;
        const toAddress = ctx.session.simpleToAddress;

        const loadingMsg = await ctx.reply('🔄 İşlem blockchain\'e gönderiliyor...\n\n⏳ Lütfen bekleyin...');
        const confirmationCallback = SendHandlers.createConfirmationCallback(ctx);
        const result = await walletService.sendUsdt(telegramId, walletId, toAddress, amount, masterPassword, confirmationCallback);

        delete ctx.session.simpleWalletId;
        delete ctx.session.simpleAmount;
        delete ctx.session.simpleToAddress;
        delete ctx.session.waitingFor;

        const initialMessage = `📤 **İşlem Blockchain'e Gönderildi!**

🔗 **Transaction Hash:**
\`${result.txHash}\`

⏳ Confirmation bekleniyor...`;

        await ctx.reply(initialMessage, { parse_mode: 'Markdown' });

      } catch (error) {
        logger.error('Simple send password error:', error);
        
        delete ctx.session.simpleWalletId;
        delete ctx.session.simpleAmount;
        delete ctx.session.simpleToAddress;
        delete ctx.session.waitingFor;

        let errorMessage = '❌ İşlem başarısız!\n\n';
        
        if (error.message.includes('Yetersiz')) {
          errorMessage += '💰 Yetersiz bakiye.';
        } else if (error.message.includes('decrypt')) {
          errorMessage += '🔐 Yanlış master şifre.';
        } else {
          errorMessage += `🔍 Hata: ${error.message}`;
        }

        await ctx.reply(errorMessage);
      }
    };
  }

  // MULTISEND BAŞLAT
  static handleMultiSend() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);
        
        if (!wallets || wallets.length === 0) {
          await ctx.reply('❌ Hiç cüzdanınız yok! Önce /addwallet ile cüzdan ekleyin.');
          return;
        }

        await ctx.reply(`📤 **Toplu USDT Gönderimi**

🔸 **Format:**
Her satıra bir işlem yazın:
\`hedef_adres miktar\`

**Örnek:**
\`TK36L4ssjceA4qSmwVsFaysEnXbMkTcGgC 100\`
\`TLh123456789abcdefghijklmnopqrstuvwxyz 50\`
\`TMn987654321zyxwvutsrqponmlkjihgfedcba 25\`

⚠️ **Tüm adresleri ve miktarları yazıp Enter'a basın:**

💡 **İptal için:** /cancel`, { parse_mode: 'Markdown' });

        ctx.session.waitingFor = 'multisend_data';

      } catch (error) {
        logger.error('Multisend start error:', error);
        await ctx.reply('❌ İşlem başarısız! Tekrar deneyin.');
      }
    };
  }

  // MULTISEND VERİLERİNİ İŞLE
  static handleMultiSendData() {
    return async (ctx) => {
      try {
        const text = ctx.message.text.trim();
        const lines = text.split('\n').filter(line => line.trim());
        
        if (lines.length === 0) {
          await ctx.reply('❌ Hiç işlem bulunamadı! Tekrar yazın:');
          return;
        }

        if (lines.length > 50) {
          await ctx.reply('❌ Maksimum 50 işlem gönderebilirsiniz! Tekrar yazın:');
          return;
        }

        const transactions = [];
        let totalAmount = 0;
        let hasError = false;

        // Her satırı işle
        for (let i = 0; i < lines.length; i++) {
          const parts = lines[i].trim().split(' ');
          
          if (parts.length !== 2) {
            await ctx.reply(`❌ **Satır ${i + 1} hatalı!**
Format: \`hedef_adres miktar\`
Tekrar yazın:`);
            hasError = true;
            break;
          }

          const [toAddress, amount] = parts;
          
          // Validasyon
          if (!toAddress.startsWith('T') || toAddress.length !== 34) {
            await ctx.reply(`❌ **Satır ${i + 1}: Geçersiz TRON adresi!**
Tekrar yazın:`);
            hasError = true;
            break;
          }
          
          if (isNaN(amount) || parseFloat(amount) <= 0) {
            await ctx.reply(`❌ **Satır ${i + 1}: Geçersiz miktar!**
Tekrar yazın:`);
            hasError = true;
            break;
          }

          transactions.push({
            toAddress: toAddress,
            amount: parseFloat(amount)
          });
          
          totalAmount += parseFloat(amount);
        }

        if (hasError) return;

        // Özet göster
        let summary = `📋 **Toplu İşlem Özeti**

📊 **Toplam:** ${transactions.length} işlem
💰 **Toplam Miktar:** ${totalAmount} USDT

**İşlemler:**\n`;

        transactions.forEach((tx, index) => {
          summary += `${index + 1}. \`${tx.toAddress.substring(0, 8)}...\` → ${tx.amount} USDT\n`;
        });

        summary += `\n⚠️ **Master şifrenizi girin:**`;

        await ctx.reply(summary, { 
          parse_mode: 'Markdown',
          reply_markup: {
            inline_keyboard: [[
              { text: '❌ İptal', callback_data: 'cancel_multisend' }
            ]]
          }
        });

        // Session'a kaydet
        ctx.session.multiTransactions = transactions;
        ctx.session.waitingFor = 'multisend_password';

      } catch (error) {
        logger.error('Multisend data error:', error);
        await ctx.reply('❌ İşlem başarısız! Tekrar deneyin.');
      }
    };
  }

  // MULTISEND MASTER ŞİFRE
  static handleMultiSendPassword() {
    return async (ctx) => {
      try {
        const masterPassword = ctx.message.text.trim();
        
        if (masterPassword.length < 8) {
          await ctx.reply('❌ Şifre çok kısa! Master şifrenizi girin:');
          return;
        }

        const telegramId = ctx.from.id;
        const transactions = ctx.session.multiTransactions;

        // Cüzdan seçimi (ilk aktif cüzdanı kullan)
        const wallets = await walletService.getUserWallets(telegramId);
        if (!wallets || wallets.length === 0) {
          await ctx.reply('❌ Hiç cüzdanınız yok!');
          return;
        }

        const activeWallet = wallets[0];

        // Loading mesajı
        let loadingMsg = await ctx.reply(`🔄 **Toplu işlem başlatılıyor...**

📊 ${transactions.length} işlem blockchain'e gönderiliyor...
⏳ Lütfen bekleyin...`);

        let successCount = 0;
        let failCount = 0;
        const results = [];

        // Her işlemi sırayla gönder
        for (let i = 0; i < transactions.length; i++) {
          const tx = transactions[i];
          
          try {
            await ctx.reply(`🔄 **İşlem ${i + 1}/${transactions.length}**

📤 Gönderiliyor: ${tx.amount} USDT
📥 Alıcı: \`${tx.toAddress.substring(0, 8)}...\`
⏳ Lütfen bekleyin...`, { parse_mode: 'Markdown' });

            // Confirmation callback (sadece hash göster, detay gösterme)
            const simpleCallback = async (telegramId, confirmationData) => {
              // Toplu işlemde tek tek notification gösterme
            };

            const result = await walletService.sendUsdt(telegramId, activeWallet.id, tx.toAddress, tx.amount, masterPassword, simpleCallback);
            
            results.push({
              ...tx,
              success: true,
              txHash: result.txHash
            });
            
            successCount++;
            logger.info(`Multisend ${i + 1}/${transactions.length} SUCCESS: ${tx.amount} USDT -> ${tx.toAddress}`);

          } catch (error) {
            results.push({
              ...tx,
              success: false,
              error: error.message
            });
            
            failCount++;
            logger.error(`Multisend ${i + 1}/${transactions.length} FAILED: ${error.message}`);
          }

          // Rate limiting için ara
          if (i < transactions.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 5000)); // 5 saniye ara
          }
        }

        // Session temizle
        delete ctx.session.multiTransactions;
        delete ctx.session.waitingFor;

        // Sonuç özeti
        let resultMessage = `✅ **Toplu İşlem Tamamlandı!**

📊 **Özet:**
✅ Başarılı: ${successCount}
❌ Başarısız: ${failCount}
📋 Toplam: ${transactions.length}

**Detaylar:**\n`;

        results.forEach((result, index) => {
          if (result.success) {
            resultMessage += `${index + 1}. ✅ ${result.amount} USDT → \`${result.toAddress.substring(0, 8)}...\`\n   TX: \`${result.txHash}\`\n`;
          } else {
            resultMessage += `${index + 1}. ❌ ${result.amount} USDT → \`${result.toAddress.substring(0, 8)}...\`\n   Hata: ${result.error}\n`;
          }
        });

        await ctx.reply(resultMessage, { parse_mode: 'Markdown' });

        logger.info(`Multisend completed: ${successCount}/${transactions.length} successful - User: ${telegramId}`);
        // PDF raporu oluştur ve gönder
        try {
          const pdfResult = await pdfService.generateMultisendReport(telegramId, results, transactions.reduce((sum, tx) => sum + tx.amount, 0));
          
          if (pdfResult.success) {
            await ctx.replyWithDocument({
              source: pdfResult.filePath,
              filename: pdfResult.fileName
            }, {
              caption: `📄 **Multisend Raporu**

📊 **Özet:**
✅ Başarılı: ${successCount}
❌ Başarısız: ${failCount}
📋 Toplam: ${transactions.length}

📁 Dosya boyutu: ${(pdfResult.size / 1024).toFixed(1)} KB`,
              parse_mode: 'Markdown'
            });
            
            logger.info(`📄 Multisend raporu gönderildi: ${pdfResult.fileName}`);
          }
        } catch (pdfError) {
          logger.error('📄 Rapor oluşturma hatası:', pdfError);
        }

      } catch (error) {
        logger.error('Multisend password error:', error);
        
        // Session temizle
        delete ctx.session.multiTransactions;
        delete ctx.session.waitingFor;

        await ctx.reply('❌ Toplu işlem başarısız!');
      }
    };
  }
}

module.exports = SendHandlers;
