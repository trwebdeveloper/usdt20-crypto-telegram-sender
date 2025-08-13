#!/bin/bash
echo "🔧 Wallet Handler düzeltiliyor..."

cat > src/bot/handlers/wallet.js << 'HANDLEREOF'
const walletService = require('../../blockchain/wallet');
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
          await ctx.editMessageText('📭 Henüz hiç cüzdanınız yok.\n\n➕ Cüzdan eklemek için /addwallet komutunu kullanın.');
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

        await ctx.editMessageText(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard.reply_markup
        });

      } catch (error) {
        logger.error('Wallet list hatası:', error);
        await ctx.reply('❌ Cüzdan listesi alınamadı.');
      }
    };
  }

  static checkBalances() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        
        await ctx.editMessageText('🔄 Bakiyeler kontrol ediliyor, lütfen bekleyin...');
        
        const walletsWithBalances = await walletService.getWalletBalances(telegramId);

        if (walletsWithBalances.length === 0) {
          await ctx.editMessageText('📭 Henüz hiç cüzdanınız yok.');
          return;
        }

        let message = `💰 *Cüzdan Bakiyeleri*\n\n`;
        let totalUsdt = 0;
        let totalTrx = 0;

        walletsWithBalances.forEach((wallet, index) => {
          const shortAddress = `${wallet.address.substring(0, 6)}...${wallet.address.substring(-4)}`;
          message += `${index + 1}. *${wallet.name}*\n`;
          message += `   📍 \`${shortAddress}\`\n`;
          
          if (wallet.balances.error) {
            message += `   ❌ ${wallet.balances.error}\n\n`;
          } else {
            message += `   💵 ${wallet.balances.usdt} USDT\n`;
            message += `   ⚡ ${wallet.balances.trx} TRX\n\n`;
            totalUsdt += wallet.balances.usdt;
            totalTrx += wallet.balances.trx;
          }
        });

        message += `📊 *Toplam Bakiye:*\n`;
        message += `💵 ${totalUsdt.toFixed(6)} USDT\n`;
        message += `⚡ ${totalTrx.toFixed(6)} TRX`;

        const keyboard = Markup.inlineKeyboard([
          [Markup.button.callback('🔄 Yenile', 'check_balances')],
          [Markup.button.callback('⬅️ Ana Menü', 'wallet_menu')]
        ]);

        await ctx.editMessageText(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard.reply_markup
        });

      } catch (error) {
        logger.error('Balance check hatası:', error);
        await ctx.editMessageText('❌ Bakiyeler alınamadı. Lütfen tekrar deneyin.');
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
        const walletInfo = tronService.getWalletFromPrivateKey(privateKey);
        
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

        const telegramId = ctx.from.id; // Telegram ID kullan
        const userInfo = {
          username: ctx.from.username,
          first_name: ctx.from.first_name
        };

        const result = await walletService.addWallet(
          telegramId,  // Telegram ID gönder
          ctx.session.privateKey, 
          ctx.session.walletName, 
          masterPassword,
          userInfo // User bilgilerini de gönder
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
HANDLEREOF

echo "✅ Wallet Handler düzeltildi!"
