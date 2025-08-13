const db = require('../database');
const tronService = require('../blockchain/tron');
const securityService = require('./securityService');
const logger = require('../utils/logger');

class WalletService {
  async getUserWallets(telegramId) {
    try {
      const query = `
        SELECT * FROM wallets 
        WHERE user_id = (SELECT id FROM users WHERE telegram_id = ?) 
        AND is_active = 1
        ORDER BY created_at ASC
      `;
      
      const wallets = await db.all(query, [telegramId]);
      return wallets || [];
    } catch (error) {
      logger.error('Get user wallets error:', error);
      return [];
    }
  }

  async addWallet(telegramId, privateKey, walletName, masterPassword) {
    try {
      // Kullanıcıyı bul veya oluştur
      let user = await db.get('SELECT * FROM users WHERE telegram_id = ?', [telegramId]);
      
      if (!user) {
        await db.run(
          'INSERT INTO users (telegram_id, created_at) VALUES (?, ?)',
          [telegramId, new Date().toISOString()]
        );
        user = await db.get('SELECT * FROM users WHERE telegram_id = ?', [telegramId]);
      }

      // Private key'den adres çıkar
      const address = tronService.getAddressFromPrivateKey(privateKey);
      
      // Private key'i şifrele
      const encryptedPrivateKey = securityService.encryptPrivateKey(privateKey, masterPassword);

      // Cüzdanı veritabanına ekle
      const result = await db.run(
        `INSERT INTO wallets (user_id, name, address, encrypted_private_key, created_at, is_active) 
         VALUES (?, ?, ?, ?, ?, 1)`,
        [user.id, walletName, address, encryptedPrivateKey, new Date().toISOString()]
      );

      logger.info(`Wallet added: ${walletName} for user ${telegramId}`);
      
      return {
        id: result.lastID,
        name: walletName,
        address: address
      };

    } catch (error) {
      logger.error('Add wallet error:', error);
      throw error;
    }
  }

  async sendUsdt(telegramId, walletId, toAddress, amount, masterPassword, confirmationCallback) {
    try {
      // Cüzdanı getir
      const wallet = await db.get(
        `SELECT w.*, u.telegram_id FROM wallets w 
         JOIN users u ON w.user_id = u.id 
         WHERE w.id = ? AND u.telegram_id = ? AND w.is_active = 1`,
        [walletId, telegramId]
      );

      if (!wallet) {
        throw new Error('Cüzdan bulunamadı!');
      }

      // Private key'i çöz
      const privateKey = securityService.decryptPrivateKey(wallet.encrypted_private_key, masterPassword);

      // USDT transferi yap
      const result = await tronService.sendUsdt(privateKey, toAddress, amount, telegramId, confirmationCallback);

      // İşlemi veritabanına kaydet
      await db.run(
        `INSERT INTO transactions (user_id, from_wallet, to_address, amount, tx_hash, status, created_at) 
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          wallet.user_id,
          wallet.address,
          toAddress,
          amount,
          result.txHash,
          result.status || 'broadcast',
          new Date().toISOString()
        ]
      );

      logger.info(`USDT transfer başlatıldı: ${amount} USDT - User: ${telegramId} - TX: ${result.txHash}`);

      return result;

    } catch (error) {
      logger.error('Send USDT error:', error);
      throw error;
    }
  }



  async getWalletBalances(telegramId) {
    try {
      const wallets = await this.getUserWallets(telegramId);
      const balances = [];
      
      for (const wallet of wallets) {
        try {
          const balance = await tronService.getBalance(wallet.address);
          balances.push({
            ...wallet,
            trx: balance?.trx || 0,
            usdt: balance?.usdt || 0,
            error: balance?.error || null
          });
        } catch (error) {
          balances.push({
            ...wallet,
            trx: 0,
            usdt: 0,
            error: error.message
          });
        }
      }
      
      return balances;
    } catch (error) {
      logger.error("Get wallet balances error:", error);
      throw error;
    }
  }
  async getWalletBalance(walletId, telegramId) {
    try {
      const wallet = await db.get(
        `SELECT w.* FROM wallets w 
         JOIN users u ON w.user_id = u.id 
         WHERE w.id = ? AND u.telegram_id = ? AND w.is_active = 1`,
        [walletId, telegramId]
      );

      if (!wallet) {
        throw new Error('Cüzdan bulunamadı!');
      }

      const balances = await tronService.getBalance(wallet.address);
      return balances;

    } catch (error) {
      logger.error('Get wallet balance error:', error);
      throw error;
    }
  }
}

module.exports = new WalletService();
