#!/bin/bash
echo "🔧 USDT bakiye NaN hatası düzeltiliyor..."

cat > src/blockchain/tron.js << 'TRONEOF'
const TronWeb = require('tronweb');
const logger = require('../utils/logger');

class TronService {
  constructor() {
    this.tronWeb = null;
    this.usdtContractAddress = process.env.USDT_CONTRACT_ADDRESS || 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t';
    this.network = process.env.TRON_NETWORK || 'mainnet';
    this.init();
  }

  init() {
    try {
      const fullHost = this.network === 'mainnet' 
        ? 'https://api.trongrid.io'
        : 'https://api.shasta.trongrid.io';

      this.tronWeb = new TronWeb({
        fullHost: fullHost,
        headers: { 
          "TRON-PRO-API-KEY": process.env.TRON_GRID_API_KEY || ''
        },
        privateKey: '01' // Dummy private key
      });

      logger.info(`✅ TRON servis başlatıldı: ${this.network}`);
    } catch (error) {
      logger.error('❌ TRON servis başlatma hatası:', error);
      throw error;
    }
  }

  generateWallet() {
    try {
      const account = this.tronWeb.utils.accounts.generateAccount();
      return {
        address: account.address,
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
      if (!privateKey || privateKey.length !== 64) {
        throw new Error('Geçersiz private key formatı');
      }

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
    try {
      return this.tronWeb.isAddress(address);
    } catch (error) {
      return false;
    }
  }

  async getTrxBalance(address) {
    try {
      const balance = await this.tronWeb.trx.getBalance(address);
      return this.tronWeb.fromSun(balance);
    } catch (error) {
      logger.error('TRX bakiye hatası:', error);
      return '0';
    }
  }

  async getUsdtBalance(address) {
    try {
      // USDT contract ile bakiye sorgula
      const contract = await this.tronWeb.contract().at(this.usdtContractAddress);
      const result = await contract.balanceOf(address).call();
      
      // BigNumber kontrolü ve dönüşümü
      let balance;
      if (result && result._hex) {
        // Hex değeri varsa
        balance = this.tronWeb.BigNumber(result._hex).dividedBy(1000000);
      } else if (result) {
        // Direkt değer varsa
        balance = this.tronWeb.BigNumber(result.toString()).dividedBy(1000000);
      } else {
        return '0.000000';
      }
      
      const balanceStr = balance.toFixed(6);
      
      // NaN kontrolü
      if (isNaN(parseFloat(balanceStr))) {
        logger.warn(`USDT bakiye NaN: ${address}, raw result:`, result);
        return '0.000000';
      }
      
      return balanceStr;
      
    } catch (error) {
      logger.error('USDT bakiye hatası:', error.message);
      // TRON Grid API key yoksa fallback
      if (error.message.includes('API') || error.message.includes('rate limit')) {
        logger.warn('TRON Grid API problemi, 0 USDT döndürülüyor');
      }
      return '0.000000';
    }
  }

  async getAllBalances(address) {
    try {
      // Paralel olarak bakiyeleri al
      const [trxBalance, usdtBalance] = await Promise.allSettled([
        this.getTrxBalance(address),
        this.getUsdtBalance(address)
      ]);

      const trx = trxBalance.status === 'fulfilled' ? parseFloat(trxBalance.value) : 0;
      const usdt = usdtBalance.status === 'fulfilled' ? parseFloat(usdtBalance.value) : 0;

      // NaN kontrolü
      const finalTrx = isNaN(trx) ? 0 : trx;
      const finalUsdt = isNaN(usdt) ? 0 : usdt;

      return {
        address,
        trx: finalTrx,
        usdt: finalUsdt
      };
    } catch (error) {
      logger.error('Bakiye alma hatası:', error);
      return {
        address,
        trx: 0,
        usdt: 0,
        error: 'Bakiye alınamadı'
      };
    }
  }

  async sendUsdt(fromPrivateKey, toAddress, amount) {
    try {
      const tempTronWeb = new TronWeb({
        fullHost: this.network === 'mainnet' 
          ? 'https://api.trongrid.io'
          : 'https://api.shasta.trongrid.io',
        headers: { 
          "TRON-PRO-API-KEY": process.env.TRON_GRID_API_KEY || ''
        },
        privateKey: fromPrivateKey
      });

      const fromAddress = tempTronWeb.address.fromPrivateKey(fromPrivateKey);
      const amountInSun = tempTronWeb.BigNumber(amount).multipliedBy(1000000);
      const contract = await tempTronWeb.contract().at(this.usdtContractAddress);

      const transaction = await contract.transfer(toAddress, amountInSun).send({
        feeLimit: 50000000,
        callValue: 0
      });

      logger.info(`✅ USDT transfer başlatıldı: ${transaction}`);

      return {
        txHash: transaction,
        from: fromAddress,
        to: toAddress,
        amount: parseFloat(amount),
        status: 'pending'
      };

    } catch (error) {
      logger.error('❌ USDT transfer hatası:', error);
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

  async testConnection() {
    try {
      const latestBlock = await this.tronWeb.trx.getCurrentBlock();
      logger.info(`✅ TRON ağı bağlantısı başarılı. Son blok: ${latestBlock.block_header.raw_data.number}`);
      return true;
    } catch (error) {
      logger.error('❌ TRON ağı bağlantı testi başarısız:', error);
      return false;
    }
  }
}

module.exports = new TronService();
TRONEOF

echo "✅ USDT bakiye NaN hatası düzeltildi!"
