const { Telegraf, Markup } = require('telegraf');
const LocalSession = require('telegraf-session-local');
const BasicHandlers = require('./handlers/basic');
const WalletHandlers = require('./handlers/wallet');
const SendHandlers = require('./handlers/send');
const HistoryHandlers = require('./handlers/history');
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

    // Send commands - YENİ KOMUTLAR!
    this.bot.command('send', SendHandlers.handleSimpleSend());
    this.bot.command('multisend', SendHandlers.handleMultiSend());

    // History commands - YENİ!
    this.bot.command('history', HistoryHandlers.transactionHistory());
    this.bot.command('transactions', HistoryHandlers.transactionHistory());

    // Cancel command
    this.bot.command('cancel', (ctx) => {
      // Tüm session'ları temizle
      delete ctx.session.waitingFor;
      delete ctx.session.sendWalletId;
      delete ctx.session.sendToAddress;
      delete ctx.session.sendAmount;
      delete ctx.session.simpleWalletId;
      delete ctx.session.simpleAmount;
      delete ctx.session.simpleToAddress;
      delete ctx.session.multiTransactions;
      delete ctx.session.privateKey;
      delete ctx.session.walletName;
      delete ctx.session.walletAddress;
      delete ctx.session.step;
      ctx.reply('❌ İşlem iptal edildi.');
    });

    // Text message handling for sessions
    this.bot.on('text', (ctx) => {
      const text = ctx.message.text;
      
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
            case 'simple_send_password':
              return SendHandlers.handleSimpleSendPassword()(ctx);
            case 'multisend_data':
              return SendHandlers.handleMultiSendData()(ctx);
            case 'multisend_password':
              return SendHandlers.handleMultiSendPassword()(ctx);
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

    // History callbacks - YENİ!

    // Cancel callbacks
    this.bot.action('send_cancel', (ctx) => {
      ctx.editMessageText('❌ İşlem iptal edildi.');
    });

    this.bot.action('cancel_multisend', (ctx) => {
      delete ctx.session.multiTransactions;
      delete ctx.session.waitingFor;
      ctx.editMessageText('❌ Toplu işlem iptal edildi.');
    });
  }

  setupErrorHandling() {
    this.bot.catch((err, ctx) => {
      logger.error('Bot error:', err);
      if (ctx) {
        ctx.reply('❌ Bir hata oluştu. Lütfen tekrar deneyin.');
      }
    });

    process.on('unhandledRejection', (reason, promise) => {
      logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    });

    process.on('uncaughtException', (error) => {
      logger.error('Uncaught Exception:', error);
      process.exit(1);
    });
  }

  start() {
    this.bot.launch()
      .then(() => {
        logger.info('🤖 Telegram bot başlatıldı!');
      })
      .catch(error => {
        logger.error('Bot başlatma hatası:', error);
      });

    // Graceful stop
    process.once('SIGINT', () => this.bot.stop('SIGINT'));
    process.once('SIGTERM', () => this.bot.stop('SIGTERM'));
  }
}

module.exports = CryptoBot;
