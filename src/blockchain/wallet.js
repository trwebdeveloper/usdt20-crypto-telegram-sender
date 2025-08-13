const tronService = require('./tron');
const encryptionService = require('../security/encryption');
const db = require('../database');
const logger = require('../utils/logger');

class WalletService {
  
  // Telegram ID'den internal user ID al
  async getOrCreateUser(telegramId, userInfo = {}) {
    try {
      let user = await db.User.findOne({
        where: { telegram_id: telegramId }
      });

      if (!user) {
        user = await db.User.create({
          telegram_id: telegramId,
          username: userInfo.username,
          first_name: userInfo.first_name,
          last_activity: new Date()
        });
        logger.info(`Yeni kullanıcı oluşturuldu: ${telegramId}`);
      } else {
        // Kullanıcı bilgilerini güncelle
        await user.update({
          username: userInfo.username,
          first_name: userInfo.first_name,
          last_activity: new Date()
        });
      }

      return user.id; // Internal database ID döndür
    } catch (error) {
      logger.error('User creation/fetch error:', error);
      throw new Error('Kullanıcı işlemi başarısız');
    }
  }

  // Kullanıcının cüzdanlarını getir
  async getUserWallets(telegramId) {
    try {
      const userId = await this.getOrCreateUser(telegramId);
      
      const wallets = await db.Wallet.findAll({
        where: { user_id: userId, is_active: true },
        attributes: ['id', 'name', 'address', 'created_at']
      });

      return wallets.map(wallet => ({
        id: wallet.id,
        name: wallet.name,
        address: wallet.address,
        created_at: wallet.created_at
      }));

    } catch (error) {
      logger.error('Cüzdan listesi hatası:', error);
      throw new Error('Cüzdanlar getirilemedi');
    }
  }

  // Yeni cüzdan ekle
  async addWallet(telegramId, privateKey, walletName, masterPassword, userInfo = {}) {
    try {
      // Internal user ID al
      const userId = await this.getOrCreateUser(telegramId, userInfo);

      // Private key doğrula
      const walletInfo = tronService.getWalletFromPrivateKey(privateKey);
      
      if (!walletInfo.isValid) {
        throw new Error('Geçersiz private key');
      }

      // Cüzdan zaten var mı kontrol et
      const existingWallet = await db.Wallet.findOne({
        where: { address: walletInfo.address, user_id: userId }
      });

      if (existingWallet) {
        throw new Error('Bu cüzdan zaten ekli');
      }

      // Private key'i şifrele
      const encryptedData = encryptionService.encryptPrivateKey(privateKey, masterPassword);

      // Veritabanına kaydet
      const wallet = await db.Wallet.create({
        user_id: userId, // Internal database ID kullan
        name: walletName,
        address: walletInfo.address,
        encrypted_private_key: encryptedData.encrypted,
        salt: encryptedData.salt,
        iv: encryptedData.iv,
        tag: encryptedData.tag,
        is_active: true
      });

      logger.info(`Yeni cüzdan eklendi: ${walletInfo.address} - User: ${telegramId}`);

      return {
        id: wallet.id,
        name: wallet.name,
        address: wallet.address
      };

    } catch (error) {
      logger.error('Cüzdan ekleme hatası:', error);
      throw error;
    }
  }

  // Cüzdan bakiyelerini getir
  async getWalletBalances(telegramId) {
    try {
      const wallets = await this.getUserWallets(telegramId);
      const balances = [];

      for (const wallet of wallets) {
        try {
          const balance = await tronService.getAllBalances(wallet.address);
          balances.push({
            ...wallet,
            balances: balance
          });
        } catch (error) {
          logger.warn(`Bakiye alınamadı: ${wallet.address}`);
          balances.push({
            ...wallet,
            balances: { trx: 0, usdt: 0, error: 'Bakiye alınamadı' }
          });
        }
      }

      return balances;

    } catch (error) {
      logger.error('Cüzdan bakiyeleri hatası:', error);
      throw new Error('Bakiyeler getirilemedi');
    }
  }

  // Private key'i çöz ve transfer yap - ASYNC CALLBACK ile
  async sendUsdt(telegramId, walletId, toAddress, amount, masterPassword, sendUpdateCallback) {
    try {
      const userId = await this.getOrCreateUser(telegramId);

      const wallet = await db.Wallet.findOne({
        where: { id: walletId, user_id: userId, is_active: true }
      });

      if (!wallet) {
        throw new Error('Cüzdan bulunamadı');
      }

      const encryptedData = {
        encrypted: wallet.encrypted_private_key,
        salt: wallet.salt,
        iv: wallet.iv,
        tag: wallet.tag
      };

      const privateKey = encryptionService.decryptPrivateKey(encryptedData, masterPassword);

      if (!tronService.isValidAddress(toAddress)) {
        throw new Error('Geçersiz hedef adres');
      }

      const balance = await tronService.getUsdtBalance(wallet.address);
      if (parseFloat(balance) < parseFloat(amount)) {
        throw new Error('Yetersiz bakiye');
      }

      // Asenkron transfer - callback ile
      const result = await tronService.sendUsdt(privateKey, toAddress, amount, telegramId, sendUpdateCallback);

      // İşlemi veritabanına kaydet
      await db.Transaction.create({
        user_id: userId,
        from_wallet: wallet.address,
        to_address: toAddress,
        amount: amount,
        tx_hash: result.txHash,
        status: 'pending'
      });

      logger.info(`USDT transfer başlatıldı: ${amount} USDT ${wallet.address} -> ${toAddress}`);

      return result;

    } catch (error) {
      logger.error('Transfer hatası:', error);
      throw error;
    }
  }

  // Cüzdan sil
  async removeWallet(telegramId, walletId) {
    try {
      const userId = await this.getOrCreateUser(telegramId);

      const result = await db.Wallet.update(
        { is_active: false },
        { where: { id: walletId, user_id: userId } }
      );

      if (result[0] === 0) {
        throw new Error('Cüzdan bulunamadı');
      }

      logger.info(`Cüzdan silindi: wallet_id=${walletId}, telegram_id=${telegramId}`);
      return true;

    } catch (error) {
      logger.error('Cüzdan silme hatası:', error);
      throw error;
    }
  }
}

module.exports = new WalletService();
