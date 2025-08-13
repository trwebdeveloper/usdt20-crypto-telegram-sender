#!/bin/bash
echo "🔧 Bot index send handling ekleniyor..."

cat > src/bot/index.js << 'BOTEOF'
const { Telegraf, Markup } = require('telegraf');
const LocalSession = require('telegraf-session-local');
const BasicHandlers = require('./handlers/basic');
const WalletHandlers = require('./handlers/wallet');
const SendHandlers = require('./handlers/send');
const logger = require('../utils/logger');

class CryptoBot {
  constructor(token) {
    this.bot = new Telegraf(token);
    
    // Session middleware ekle
    const localSession = new LocalSession({ 
      database: 'sessions.json',
      property: 'session',
      storage: LocalSession.storageFileSync,
      format: {
        serialize: (obj) => JSON.stringify(obj),
        deserialize: (str) => JSON.parse(str),
      }
    });
    
    this.bot.use(localSession.middleware());
    
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

    // Cancel command
    this.bot.command('cancel', (ctx) => {
      // Tüm session'ları temizle
      delete ctx.session.waitingFor;
      delete ctx.session.sendWalletId;
      delete ctx.session.sendToAddress;
      delete ctx.session.sendAmount;
      delete ctx.session.privateKey;
      delete ctx.session.walletName;
      delete ctx.session.walletAddress;
      delete ctx.session.step;
      ctx.reply('❌ İşlem iptal edildi.');
    });

    // History and status commands
    this.bot.command('history', (ctx) => {
      ctx.reply('📊 İşlem geçmişi özelliği yakında eklenecek...');
    });

    this.bot.command('status', (ctx) => {
      ctx.reply('🔍 İşlem durumu sorgulama özelliği yakında eklenecek...');
    });

    // Text message handling for sessions
    this.bot.on('text', (ctx) => {
      const text = ctx.message.text;
      
      // Cancel komutu
      if (text === '/cancel') {
        delete ctx.session.waitingFor;
        delete ctx.session.sendWalletId;
        delete ctx.session.sendToAddress;
        delete ctx.session.sendAmount;
        delete ctx.session.privateKey;
        delete ctx.session.walletName;
        delete ctx.session.walletAddress;
        delete ctx.session.step;
        ctx.reply('❌ İşlem iptal edildi.');
        return;
      }
      
      // Komut değilse session kontrol et
      if (!text.startsWith('/')) {
        if (ctx.session && ctx.session.waitingFor) {
          switch (ctx.session.waitingFor) {
            case 'private_key':
              return WalletHandlers.handlePrivateKey()(ctx);
            case 'wallet_name':
              return WalletHandlers.handleWalletName()(ctx);
            case 'master_password':
              return WalletHandlers.handleMasterPassword()(ctx);
            case 'send_address':
              return SendHandlers.handleSendAddress()(ctx);
            case 'send_amount':
              return SendHandlers.handleSendAmount()(ctx);
            case 'send_password':
              return SendHandlers.handleSendPassword()(ctx);
            default:
              ctx.reply('💡 Komut listesi için /help yazın.');
          }
        } else {
          ctx.reply('💡 Komut listesi için /help yazın.');
        }
      }
    });
  }

  setupCallbacks() {
    // Wallet callbacks
    this.bot.action('wallet_menu', WalletHandlers.walletMenu());
    this.bot.action('wallets_list', WalletHandlers.walletsList());
    this.bot.action('check_balances', WalletHandlers.checkBalances());
    this.bot.action('add_wallet', WalletHandlers.addWalletStart());

    // Send callbacks
    this.bot.action(/^send_from_(\d+)$/, SendHandlers.selectWallet());
    this.bot.action('send_cancel', SendHandlers.cancelSend());

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
        ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      } else {
        ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
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
BOTEOF

echo "✅ Bot index send handling eklendi!"
