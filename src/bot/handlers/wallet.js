const walletService = require("../../services/walletService");
const tronService = require('../../blockchain/tron');
const logger = require('../../utils/logger');
const { Markup } = require('telegraf');

class WalletHandlers {

  static walletMenu() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);

        const keyboard = Markup.inlineKeyboard([
          [Markup.button.callback('💼 Cüzdanlarım', 'wallets_list')],
          [Markup.button.callback('➕ Cüzdan Ekle', 'add_wallet')],
          [Markup.button.callback('💰 Bakiyeler', 'check_balances')],
          [Markup.button.callback('📊 İşlem Geçmişi', 'transaction_history')]
        ]);

        const message = `💼 *Cüzdan Yönetimi*

📊 Toplam cüzdan sayısı: ${wallets.length}

Ne yapmak istiyorsunuz?`;

        await ctx.reply(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard.reply_markup
        });

      } catch (error) {
        logger.error('Wallet menu hatası:', error);
        await ctx.reply('❌ Cüzdan menüsü yüklenemedi.');
      }
    };
  }

  static walletsList() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const wallets = await walletService.getUserWallets(telegramId);

        if (wallets.length === 0) {
          const message = '📭 Henüz hiç cüzdanınız yok.\n\n➕ Cüzdan eklemek için /addwallet komutunu kullanın.';
          
          if (ctx.callbackQuery) {
            await ctx.answerCbQuery();
            await ctx.reply(message);
          } else {
            await ctx.reply(message);
          }
          return;
        }

        let message = `💼 *Cüzdanlarınız (${wallets.length} adet)*\n\n`;
        
        wallets.forEach((wallet, index) => {
          const shortAddress = `${wallet.address.substring(0, 6)}...${wallet.address.substring(-4)}`;
          message += `${index + 1}. *${wallet.name}*\n`;
          message += `   📍 \`${shortAddress}\`\n`;
          message += `   📅 ${new Date(wallet.created_at).toLocaleDateString('tr-TR')}\n\n`;
        });

        const keyboard = Markup.inlineKeyboard([
          [Markup.button.callback('💰 Bakiyeleri Göster', 'check_balances')],
          [Markup.button.callback('⬅️ Ana Menü', 'wallet_menu')]
        ]);

        if (ctx.callbackQuery) {
          await ctx.answerCbQuery();
          await ctx.reply(message, {
            parse_mode: 'Markdown',
            reply_markup: keyboard.reply_markup
          });
        } else {
          await ctx.reply(message, {
            parse_mode: 'Markdown',
            reply_markup: keyboard.reply_markup
          });
        }

      } catch (error) {
        logger.error('Wallet list hatası:', error);
        if (ctx.callbackQuery) {
          await ctx.answerCbQuery();
        }
        await ctx.reply('❌ Cüzdan listesi alınamadı.');
      }
    };
  }

    static checkBalances() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const balances = await walletService.getWalletBalances(telegramId);

        if (!balances || balances.length === 0) {
          await ctx.reply('📭 Hiç cüzdanınız yok!\n\n/addwallet ile cüzdan ekleyin.');
          return;
        }

        let message = `💼 **Cüzdan Bakiyeleri**\n\n`;
        let totalUsdt = 0;
        let totalTrx = 0;

        balances.forEach((balance, index) => {
          const trx = balance?.trx || 0;
          const usdt = balance?.usdt || 0;
          
          message += `${index + 1}. **${balance.name}**\n`;
          message += `   💵 ${usdt.toFixed(6)} USDT\n`;
          message += `   ⚡ ${trx.toFixed(6)} TRX\n\n`;
          
          if (!balance.error) {
            totalUsdt += usdt;
            totalTrx += trx;
          }
        });

        message += `📊 **Toplam Bakiye:**\n`;
        message += `💵 ${totalUsdt.toFixed(6)} USDT\n`;
        message += `⚡ ${totalTrx.toFixed(6)} TRX`;

        await ctx.reply(message, { parse_mode: 'Markdown' });

      } catch (error) {
        logger.error('Balance check hatası:', error.message);
        await ctx.reply('❌ Bakiye kontrolü başarısız!');
      }
    };
  }

  static addWalletStart() {
    return async (ctx) => {
      try {
        const message = `➕ *Yeni Cüzdan Ekleme*

🔐 *Güvenlik Uyarısı:*
- Private key'inizi sadece güvenilir kaynaklardan alın
- Private key'iniz şifrelenmiş olarak saklanacak
- Bu bilgiyi kimseyle paylaşmayın

📝 Private key'inizi gönderin:`;

        if (ctx.callbackQuery) {
          await ctx.answerCbQuery();
        }

        await ctx.reply(message, { parse_mode: 'Markdown' });
        
        // Session'a durumu kaydet
        ctx.session.waitingFor = 'private_key';
        ctx.session.step = 'add_wallet';

      } catch (error) {
        logger.error('Add wallet start hatası:', error);
        await ctx.reply('❌ Cüzdan ekleme işlemi başlatılamadı.');
      }
    };
  }

  static handlePrivateKey() {
    return async (ctx) => {
      try {
        const privateKey = ctx.message.text.trim();
        
        // Private key doğrula
        if (!privateKey || privateKey.length !== 64) {
          await ctx.reply('❌ Geçersiz private key formatı!\n\n64 karakter olmalı. Tekrar deneyin:');
          return;
        }

        // Cüzdan bilgisini test et
        const address = tronService.getAddressFromPrivateKey(privateKey);
        const walletInfo = { address: address, isValid: true };
        
        if (!walletInfo.isValid) {
          await ctx.reply('❌ Geçersiz private key!\n\nLütfen geçerli bir TRON private key girin:');
          return;
        }

        // Session'a kaydet
        ctx.session.privateKey = privateKey;
        ctx.session.walletAddress = walletInfo.address;
        ctx.session.waitingFor = 'wallet_name';

        const shortAddress = `${walletInfo.address.substring(0, 8)}...${walletInfo.address.substring(-6)}`;
        
        await ctx.reply(`✅ *Geçerli Cüzdan!*

📍 Adres: \`${shortAddress}\`

📝 Bu cüzdan için bir isim verin:
(Örnek: Ana Cüzdan, İş Cüzdanı vb.)`, 
          { parse_mode: 'Markdown' }
        );

      } catch (error) {
        logger.error('Private key handle hatası:', error);
        await ctx.reply('❌ Private key işlenirken hata oluştu. Tekrar deneyin.');
      }
    };
  }

  static handleWalletName() {
    return async (ctx) => {
      try {
        const walletName = ctx.message.text.trim();
        
        if (!walletName || walletName.length < 2) {
          await ctx.reply('❌ Cüzdan ismi çok kısa!\n\nEn az 2 karakter olmalı:');
          return;
        }

        if (walletName.length > 50) {
          await ctx.reply('❌ Cüzdan ismi çok uzun!\n\nEn fazla 50 karakter olmalı:');
          return;
        }

        await ctx.reply('🔐 Master şifre belirleyin:\n\n⚠️ Bu şifre private key\'inizi şifrelemek için kullanılacak!\n🔒 Güçlü bir şifre seçin ve unutmayın!');
        
        ctx.session.walletName = walletName;
        ctx.session.waitingFor = 'master_password';

      } catch (error) {
        logger.error('Wallet name handle hatası:', error);
        await ctx.reply('❌ İsim işlenirken hata oluştu.');
      }
    };
  }

  static handleMasterPassword() {
    return async (ctx) => {
      try {
        const masterPassword = ctx.message.text.trim();
        
        if (masterPassword.length < 8) {
          await ctx.reply('❌ Şifre çok kısa!\n\nEn az 8 karakter olmalı:');
          return;
        }

        await ctx.reply('🔄 Cüzdan kaydediliyor...');

        const telegramId = ctx.from.id;
        const userInfo = {
          username: ctx.from.username,
          first_name: ctx.from.first_name
        };

        const result = await walletService.addWallet(
          telegramId,
          ctx.session.privateKey, 
          ctx.session.walletName, 
          masterPassword,
          userInfo
        );

        // Session'ı temizle
        delete ctx.session.privateKey;
        delete ctx.session.walletAddress;
        delete ctx.session.walletName;
        delete ctx.session.waitingFor;
        delete ctx.session.step;

        const shortAddress = `${result.address.substring(0, 8)}...${result.address.substring(-6)}`;

        await ctx.reply(`✅ *Cüzdan Başarıyla Eklendi!*

📝 İsim: ${result.name}
📍 Adres: \`${shortAddress}\`

🎉 Artık /balance ile bakiye sorgulayabilir, /send ile USDT gönderebilirsiniz!`, 
          { parse_mode: 'Markdown' }
        );

        logger.info(`Yeni cüzdan eklendi: ${result.address} - Telegram ID: ${telegramId}`);

      } catch (error) {
        logger.error('Master password handle hatası:', error);
        
        // Session'ı temizle
        delete ctx.session.privateKey;
        delete ctx.session.walletAddress;
        delete ctx.session.walletName;
        delete ctx.session.waitingFor;
        delete ctx.session.step;

        let errorMsg = '❌ Cüzdan eklenemedi!\n\n';
        if (error.message.includes('zaten ekli')) {
          errorMsg += 'Bu cüzdan zaten hesabınızda kayıtlı.';
        } else {
          errorMsg += 'Tekrar deneyin: /addwallet';
        }
        
        await ctx.reply(errorMsg);
      }
    };
  }
}

module.exports = WalletHandlers;
