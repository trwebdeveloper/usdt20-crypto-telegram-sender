#!/bin/bash

echo "🚀 Telegram Crypto Bot - Dosya Kurulumu Başlıyor..."

# TRON Blockchain Service
echo "📝 TRON Service oluşturuluyor..."
cat > src/blockchain/tron.js << 'EOF'
const TronWeb = require('tronweb');
const logger = require('../utils/logger');

class TronService {
  constructor() {
    this.tronWeb = null;
    this.usdtContractAddress = process.env.USDT_CONTRACT_ADDRESS;
    this.network = process.env.TRON_NETWORK || 'mainnet';
    this.init();
  }

  init() {
    try {
      const fullHost = this.network === 'mainnet' 
        ? 'https://api.trongrid.io'
        : 'https://api.shasta.trongrid.io';

      this.tronWeb = new TronWeb({
        fullHost,
        headers: { 
          "TRON-PRO-API-KEY": process.env.TRON_GRID_API_KEY || ''
        }
      });

      logger.info(`TRON servis başlatıldı: ${this.network}`);
    } catch (error) {
      logger.error('TRON servis başlatma hatası:', error);
      throw error;
    }
  }

  generateWallet() {
    try {
      const account = this.tronWeb.createAccount();
      return {
        address: account.address.base58,
        privateKey: account.privateKey,
        publicKey: account.publicKey
      };
    } catch (error) {
      logger.error('Cüzdan oluşturma hatası:', error);
      throw new Error('Cüzdan oluşturulamadı');
    }
  }

  getWalletFromPrivateKey(privateKey) {
    try {
      const address = this.tronWeb.address.fromPrivateKey(privateKey);
      return {
        address,
        privateKey,
        isValid: this.tronWeb.isAddress(address)
      };
    } catch (error) {
      logger.error('Private key doğrulama hatası:', error);
      throw new Error('Geçersiz private key');
    }
  }

  isValidAddress(address) {
    return this.tronWeb.isAddress(address);
  }

  async getTrxBalance(address) {
    try {
      const balance = await this.tronWeb.trx.getBalance(address);
      return this.tronWeb.fromSun(balance);
    } catch (error) {
      logger.error('TRX bakiye hatası:', error);
      throw new Error('TRX bakiyesi alınamadı');
    }
  }

  async getUsdtBalance(address) {
    try {
      const contract = await this.tronWeb.contract().at(this.usdtContractAddress);
      const balance = await contract.balanceOf(address).call();
      return this.tronWeb.toBigNumber(balance).dividedBy(1000000).toFixed(6);
    } catch (error) {
      logger.error('USDT bakiye hatası:', error);
      throw new Error('USDT bakiyesi alınamadı');
    }
  }

  async getAllBalances(address) {
    try {
      const [trxBalance, usdtBalance] = await Promise.all([
        this.getTrxBalance(address),
        this.getUsdtBalance(address)
      ]);

      return {
        address,
        trx: parseFloat(trxBalance),
        usdt: parseFloat(usdtBalance)
      };
    } catch (error) {
      logger.error('Bakiye alma hatası:', error);
      throw new Error('Bakiyeler alınamadı');
    }
  }

  async sendUsdt(fromPrivateKey, toAddress, amount) {
    try {
      this.tronWeb.setPrivateKey(fromPrivateKey);
      const fromAddress = this.tronWeb.address.fromPrivateKey(fromPrivateKey);
      const amountInSun = this.tronWeb.toBigNumber(amount).multipliedBy(1000000);
      const contract = await this.tronWeb.contract().at(this.usdtContractAddress);
      const transaction = await contract.transfer(toAddress, amountInSun).send({
        feeLimit: 50000000,
        callValue: 0
      });

      logger.info(`USDT transfer başlatıldı: ${transaction}`);
      return {
        txHash: transaction,
        from: fromAddress,
        to: toAddress,
        amount: parseFloat(amount),
        status: 'pending'
      };
    } catch (error) {
      logger.error('USDT transfer hatası:', error);
      throw new Error(`Transfer başarısız: ${error.message}`);
    }
  }

  async getTransactionStatus(txHash) {
    try {
      const transaction = await this.tronWeb.trx.getTransaction(txHash);
      if (!transaction) return { status: 'not_found' };
      const receipt = await this.tronWeb.trx.getTransactionInfo(txHash);
      return {
        status: receipt.result === 'SUCCESS' ? 'confirmed' : 'failed',
        blockNumber: receipt.blockNumber,
        energyUsed: receipt.receipt?.energy_usage_total || 0,
        fee: receipt.fee || 0
      };
    } catch (error) {
      logger.error('İşlem durumu hatası:', error);
      return { status: 'error', error: error.message };
    }
  }

  async estimateUsdtTransferFee() {
    return {
      estimatedFee: 20,
      currency: 'TRX',
      note: 'USDT transfer için tahmini fee'
    };
  }
}

module.exports = new TronService();
EOF

# Wallet Service
echo "📝 Wallet Service oluşturuluyor..."
cat > src/blockchain/wallet.js << 'EOF'
const tronService = require('./tron');
const encryptionService = require('../security/encryption');
const db = require('../database');
const logger = require('../utils/logger');

class WalletService {
  
  async getUserWallets(userId) {
    try {
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

  async addWallet(userId, privateKey, walletName, masterPassword) {
    try {
      const walletInfo = tronService.getWalletFromPrivateKey(privateKey);
      if (!walletInfo.isValid) throw new Error('Geçersiz private key');

      const existingWallet = await db.Wallet.findOne({
        where: { address: walletInfo.address, user_id: userId }
      });
      if (existingWallet) throw new Error('Bu cüzdan zaten ekli');

      const encryptedData = encryptionService.encryptPrivateKey(privateKey, masterPassword);
      const wallet = await db.Wallet.create({
        user_id: userId,
        name: walletName,
        address: walletInfo.address,
        encrypted_private_key: encryptedData.encrypted,
        salt: encryptedData.salt,
        iv: encryptedData.iv,
        tag: encryptedData.tag,
        is_active: true
      });

      logger.info(`Yeni cüzdan eklendi: ${walletInfo.address}`);
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

  async getWalletBalances(userId) {
    try {
      const wallets = await this.getUserWallets(userId);
      const balances = [];
      for (const wallet of wallets) {
        try {
          const balance = await tronService.getAllBalances(wallet.address);
          balances.push({ ...wallet, balances: balance });
        } catch (error) {
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

  async sendUsdt(userId, walletId, toAddress, amount, masterPassword) {
    try {
      const wallet = await db.Wallet.findOne({
        where: { id: walletId, user_id: userId, is_active: true }
      });
      if (!wallet) throw new Error('Cüzdan bulunamadı');

      const encryptedData = {
        encrypted: wallet.encrypted_private_key,
        salt: wallet.salt,
        iv: wallet.iv,
        tag: wallet.tag
      };
      const privateKey = encryptionService.decryptPrivateKey(encryptedData, masterPassword);

      if (!tronService.isValidAddress(toAddress)) throw new Error('Geçersiz hedef adres');

      const balance = await tronService.getUsdtBalance(wallet.address);
      if (parseFloat(balance) < parseFloat(amount)) throw new Error('Yetersiz bakiye');

      const result = await tronService.sendUsdt(privateKey, toAddress, amount);
      await db.Transaction.create({
        user_id: userId,
        from_wallet: wallet.address,
        to_address: toAddress,
        amount: amount,
        tx_hash: result.txHash,
        status: 'pending'
      });

      logger.info(`USDT transfer: ${amount} USDT ${wallet.address} -> ${toAddress}`);
      return result;
    } catch (error) {
      logger.error('Transfer hatası:', error);
      throw error;
    }
  }
}

module.exports = new WalletService();
EOF

# PM2 Ecosystem
echo "📝 PM2 Ecosystem oluşturuluyor..."
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'cryptobot',
    script: 'src/app.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/pm2-error.log',
    out_file: './logs/pm2-out.log',
    log_file: './logs/pm2-combined.log',
    time: true
  }]
};
EOF

echo "✅ Tüm dosyalar oluşturuldu!"
echo "🚀 Bot komutları için sonraki scripti çalıştırabilirsiniz!"
