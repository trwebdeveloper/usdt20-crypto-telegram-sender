#!/bin/bash

echo "🤖 Bot Komutları Kurulumu Başlıyor..."

# Bot Handlers - Start & Help
echo "📝 Bot handlers oluşturuluyor..."
cat > src/bot/handlers/basic.js << 'EOF'
const logger = require('../../utils/logger');
const db = require('../../database');

class BasicHandlers {
  
  static start() {
    return async (ctx) => {
      try {
        const user = ctx.from;
        logger.info(`Yeni kullanıcı: ${user.first_name} (${user.id})`);

        // Kullanıcıyı veritabanına kaydet/güncelle
        await db.User.upsert({
          telegram_id: user.id,
          username: user.username,
          first_name: user.first_name,
          last_activity: new Date()
        });

        const welcomeMessage = `🤖 *Crypto Bot'a Hoş Geldiniz!*

Merhaba ${user.first_name}! 👋

🔹 *Ana Komutlar:*
/help - Yardım menüsü
/wallet - Cüzdan yönetimi 
/balance - Bakiye sorgula
/send - USDT gönder
/history - İşlem geçmişi

🔹 *Güvenlik:*
- Private key'leriniz şifrelenmiş saklanır
- İşlemler için onay gerekir
- Günlük limitler mevcuttur

⚡ Başlamak için /wallet komutunu kullanın!`;

        await ctx.reply(welcomeMessage, { parse_mode: 'Markdown' });
      } catch (error) {
        logger.error('Start komutu hatası:', error);
        await ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    };
  }

  static help() {
    return async (ctx) => {
      const helpMessage = `📖 *Yardım Menüsü*

🔹 *Temel Komutlar:*
/start - Bot'u başlat
/help - Bu yardım menüsü
/ping - Bağlantı testi

🔹 *Cüzdan Yönetimi:*
/wallet - Cüzdan ana menüsü
/addwallet - Yeni cüzdan ekle
/wallets - Cüzdan listesi
/balance - Bakiye sorgula

🔹 *Transfer İşlemleri:*
/send - USDT gönder
/history - İşlem geçmişi
/status - İşlem durumu sorgula

🔹 *Güvenlik:*
/settings - Güvenlik ayarları
/limits - Günlük limitler

📞 *Destek:* Sorun yaşıyorsanız /ping komutu ile test edin.

⚠️ *Önemli:* Private key'lerinizi asla paylaşmayın!`;

      await ctx.reply(helpMessage, { parse_mode: 'Markdown' });
    };
  }

  static ping() {
    return async (ctx) => {
      const startTime = Date.now();
      try {
        await ctx.reply('🏓 Pong!');
        const endTime = Date.now();
        const responseTime = endTime - startTime;
        
        logger.info(`Ping komutu: ${responseTime}ms - User: ${ctx.from.id}`);
        
        if (responseTime > 1000) {
          await ctx.reply(`⚠️ Yavaş bağlantı: ${responseTime}ms`);
        }
      } catch (error) {
        logger.error('Ping komutu hatası:', error);
      }
    };
  }
}

module.exports = BasicHandlers;
EOF

# Wallet Handlers
echo "📝 Wallet handlers oluşturuluyor..."
cat > src/bot/handlers/wallet.js << 'EOF'
const walletService = require('../../blockchain/wallet');
const tronService = require('../../blockchain/tron');
const logger = require('../../utils/logger');
const { Markup } = require('telegraf');

class WalletHandlers {

  static walletMenu() {
    return async (ctx) => {
      try {
        const userId = ctx.from.id;
        const wallets = await walletService.getUserWallets(userId);

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
        const userId = ctx.from.id;
        const wallets = await walletService.getUserWallets(userId);

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
        const userId = ctx.from.id;
        
        await ctx.editMessageText('🔄 Bakiyeler kontrol ediliyor, lütfen bekleyin...');
        
        const walletsWithBalances = await walletService.getWalletBalances(userId);

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
        
        // Kullanıcıyı "waiting_private_key" durumuna al
        // Bu kısım session/scene ile yapılacak

      } catch (error) {
        logger.error('Add wallet start hatası:', error);
        await ctx.reply('❌ Cüzdan ekleme işlemi başlatılamadı.');
      }
    };
  }
}

module.exports = WalletHandlers;
EOF

# Send USDT Handlers
echo "📝 Send handlers oluşturuluyor..."
cat > src/bot/handlers/send.js << 'EOF'
const walletService = require('../../blockchain/wallet');
const tronService = require('../../blockchain/tron');
const logger = require('../../utils/logger');
const { Markup } = require('telegraf');

class SendHandlers {

  static sendMenu() {
    return async (ctx) => {
      try {
        const userId = ctx.from.id;
        const wallets = await walletService.getUserWallets(userId);

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

        buttons.push([Markup.button.callback('⬅️ Ana Menü', 'wallet_menu')]);

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

  static sendTransactionConfirm() {
    return async (ctx, walletId, toAddress, amount) => {
      try {
        const userId = ctx.from.id;
        
        // Cüzdan bilgisini al
        const wallets = await walletService.getUserWallets(userId);
        const wallet = wallets.find(w => w.id === walletId);
        
        if (!wallet) {
          await ctx.reply('❌ Cüzdan bulunamadı.');
          return;
        }

        // Bakiye kontrol et
        const balance = await tronService.getUsdtBalance(wallet.address);
        
        if (parseFloat(balance) < parseFloat(amount)) {
          await ctx.reply(`❌ Yetersiz bakiye!\n\nMevcut: ${balance} USDT\nGöndermek istenen: ${amount} USDT`);
          return;
        }

        // Fee tahmini
        const feeInfo = await tronService.estimateUsdtTransferFee();

        const shortFromAddress = `${wallet.address.substring(0, 6)}...${wallet.address.substring(-4)}`;
        const shortToAddress = `${toAddress.substring(0, 6)}...${toAddress.substring(-4)}`;

        const confirmMessage = `✅ *İşlem Onayı*

📤 *Gönderen:* ${wallet.name}
📍 \`${shortFromAddress}\`

📥 *Alıcı:*
📍 \`${shortToAddress}\`

💰 *Miktar:* ${amount} USDT
⛽ *Tahmini Fee:* ~${feeInfo.estimatedFee} TRX

🔐 Bu işlemi onaylıyor musunuz?`;

        const keyboard = Markup.inlineKeyboard([
          [
            Markup.button.callback('✅ Onayla', `confirm_send_${walletId}_${amount}_${toAddress}`),
            Markup.button.callback('❌ İptal', 'send_cancel')
          ]
        ]);

        await ctx.reply(confirmMessage, {
          parse_mode: 'Markdown',
          reply_markup: keyboard.reply_markup
        });

      } catch (error) {
        logger.error('Send confirm hatası:', error);
        await ctx.reply('❌ İşlem onayı hazırlanamadı.');
      }
    };
  }

  static executeSend() {
    return async (ctx, walletId, amount, toAddress, masterPassword) => {
      try {
        const userId = ctx.from.id;

        await ctx.editMessageText('🔄 İşlem gerçekleştiriliyor, lütfen bekleyin...');

        const result = await walletService.sendUsdt(userId, walletId, toAddress, amount, masterPassword);

        const successMessage = `✅ *İşlem Başarıyla Gönderildi!*

🔗 *Transaction Hash:*
\`${result.txHash}\`

📊 *Detaylar:*
💰 Miktar: ${amount} USDT
📤 Gönderen: \`${result.from.substring(0, 8)}...\`
📥 Alıcı: \`${toAddress.substring(0, 8)}...\`
📅 Zaman: ${new Date().toLocaleString('tr-TR')}

⏳ İşlem ağda onaylanıyor...
/status komutu ile durumu takip edebilirsiniz.`;

        await ctx.editMessageText(successMessage, { parse_mode: 'Markdown' });

        logger.info(`USDT transfer başarılı: ${amount} USDT - User: ${userId} - TX: ${result.txHash}`);

      } catch (error) {
        logger.error('Execute send hatası:', error);
        
        let errorMessage = '❌ İşlem başarısız oldu.\n\n';
        
        if (error.message.includes('Yetersiz bakiye')) {
          errorMessage += '💰 Yetersiz bakiye.';
        } else if (error.message.includes('Geçersiz')) {
          errorMessage += '📍 Geçersiz adres.';
        } else if (error.message.includes('Şifre')) {
          errorMessage += '🔐 Şifre hatası.';
        } else {
          errorMessage += `🔍 Hata: ${error.message}`;
        }

        await ctx.editMessageText(errorMessage);
      }
    };
  }
}

module.exports = SendHandlers;
EOF

# Main Bot Index
echo "📝 Bot ana dosyası oluşturuluyor..."
cat > src/bot/index.js << 'EOF'
const { Telegraf, Markup } = require('telegraf');
const BasicHandlers = require('./handlers/basic');
const WalletHandlers = require('./handlers/wallet');
const SendHandlers = require('./handlers/send');
const logger = require('../utils/logger');

class CryptoBot {
  constructor(token) {
    this.bot = new Telegraf(token);
    this.setupHandlers();
    this.setupCallbacks();
    this.setupErrorHandling();
  }

  setupHandlers() {
    // Basic commands
    this.bot.start(BasicHandlers.start());
    this.bot.help(BasicHandlers.help());
    this.bot.command('ping', BasicHandlers.ping());

    // Wallet commands
    this.bot.command('wallet', WalletHandlers.walletMenu());
    this.bot.command('wallets', WalletHandlers.walletsList());
    this.bot.command('balance', WalletHandlers.checkBalances());
    this.bot.command('addwallet', WalletHandlers.addWalletStart());

    // Send commands
    this.bot.command('send', SendHandlers.sendMenu());

    // History and status commands
    this.bot.command('history', (ctx) => {
      ctx.reply('📊 İşlem geçmişi özelliği yakında eklenecek...');
    });

    this.bot.command('status', (ctx) => {
      ctx.reply('🔍 İşlem durumu sorgulama özelliği yakında eklenecek...');
    });
  }

  setupCallbacks() {
    // Wallet callbacks
    this.bot.action('wallet_menu', WalletHandlers.walletMenu());
    this.bot.action('wallets_list', WalletHandlers.walletsList());
    this.bot.action('check_balances', WalletHandlers.checkBalances());
    this.bot.action('add_wallet', WalletHandlers.addWalletStart());

    // Send callbacks
    this.bot.action(/^send_from_(\d+)$/, (ctx) => {
      const walletId = ctx.match[1];
      ctx.reply(`📝 Hedef adres girin:\n\n⚠️ TRON (TRC20) adresini dikkatli girin!`);
      // Session handling burada olacak
    });

    this.bot.action('send_cancel', (ctx) => {
      ctx.editMessageText('❌ İşlem iptal edildi.');
    });

    // Generic callback for unknown actions
    this.bot.on('callback_query', (ctx) => {
      if (!ctx.callbackQuery.data.match(/^(wallet_|send_|check_|add_)/)) {
        ctx.answerCbQuery('🚧 Bu özellik henüz hazır değil...');
      }
    });
  }

  setupErrorHandling() {
    this.bot.catch((err, ctx) => {
      logger.error('Bot hatası:', err);
      
      if (ctx.updateType === 'callback_query') {
        ctx.answerCbQuery('❌ Bir hata oluştu');
        ctx.editMessageText('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      } else {
        ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    });

    // Handle text messages for commands
    this.bot.on('text', (ctx) => {
      const text = ctx.message.text;
      
      if (!text.startsWith('/')) {
        ctx.reply('💡 Komut listesi için /help yazın.');
      }
    });
  }

  async launch() {
    await this.bot.launch();
    logger.info('🤖 Crypto Bot başlatıldı');
    return this.bot;
  }

  stop(reason) {
    this.bot.stop(reason);
    logger.info(`🛑 Bot durdu: ${reason}`);
  }
}

module.exports = CryptoBot;
EOF

echo "✅ Bot komutları başarıyla oluşturuldu!"
echo "🔄 Artık app.js dosyasını güncelleyebilirsiniz!"
