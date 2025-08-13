#!/bin/bash
echo "🔧 BigNumber hatası düzeltiliyor..."

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
        privateKey: '01'
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
      const contract = await this.tronWeb.contract().at(this.usdtContractAddress);
      const result = await contract.balanceOf(address).call();
      
      let balance;
      if (result && result._hex) {
        balance = this.tronWeb.BigNumber(result._hex).dividedBy(1000000);
      } else if (result) {
        balance = this.tronWeb.BigNumber(result.toString()).dividedBy(1000000);
      } else {
        return '0.000000';
      }
      
      const balanceStr = balance.toFixed(6);
      
      if (isNaN(parseFloat(balanceStr))) {
        logger.warn(`USDT bakiye NaN: ${address}, raw result:`, result);
        return '0.000000';
      }
      
      return balanceStr;
      
    } catch (error) {
      logger.error('USDT bakiye hatası:', error.message);
      return '0.000000';
    }
  }

  async getAllBalances(address) {
    try {
      const [trxBalance, usdtBalance] = await Promise.allSettled([
        this.getTrxBalance(address),
        this.getUsdtBalance(address)
      ]);

      const trx = trxBalance.status === 'fulfilled' ? parseFloat(trxBalance.value) : 0;
      const usdt = usdtBalance.status === 'fulfilled' ? parseFloat(usdtBalance.value) : 0;

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
      logger.info(`USDT transfer başlatılıyor: ${amount} USDT -> ${toAddress}`);

      // Yeni TronWeb instance
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
      logger.info(`Gönderen adres: ${fromAddress}`);

      // Miktarı 6 decimal ile çevir (USDT 6 decimal)
      // String kullanarak BigNumber hatalarını önle
      const amountStr = amount.toString();
      const amountInSun = tempTronWeb.utils.toBigNumber(amountStr).multipliedBy(tempTronWeb.utils.toBigNumber('1000000'));
      
      logger.info(`Miktar (sun): ${amountInSun.toString()}`);

      // Contract instance
      const contract = await tempTronWeb.contract().at(this.usdtContractAddress);
      logger.info('Contract yüklendi');

      // Transfer parametrelerini kontrol et
      if (!tempTronWeb.isAddress(toAddress)) {
        throw new Error('Geçersiz hedef adres');
      }

      // Transfer işlemi - string değeri direkt kullan
      const transaction = await contract.transfer(toAddress, amountInSun.toString()).send({
        feeLimit: 50000000, // 50 TRX
        callValue: 0,
        shouldPollResponse: true
      });

      logger.info(`✅ USDT transfer tamamlandı: ${transaction}`);

      return {
        txHash: transaction,
        from: fromAddress,
        to: toAddress,
        amount: parseFloat(amount),
        status: 'pending'
      };

    } catch (error) {
      logger.error('❌ USDT transfer detaylı hatası:', {
        message: error.message,
        stack: error.stack,
        amount: amount,
        toAddress: toAddress
      });
      
      // Daha açıklayıcı hata mesajları
      if (error.message.includes('insufficient balance')) {
        throw new Error('Yetersiz TRX bakiyesi (fee için)');
      } else if (error.message.includes('REVERT')) {
        throw new Error('Transfer reddedildi - Yetersiz USDT bakiyesi');
      } else if (error.message.includes('BigNumber')) {
        throw new Error('Miktar formatı hatası');
      } else {
        throw new Error(`Transfer başarısız: ${error.message}`);
      }
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

echo "✅ BigNumber hatası düzeltildi!"
