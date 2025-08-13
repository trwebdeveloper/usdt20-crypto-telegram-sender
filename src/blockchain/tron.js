const TronWeb = require('tronweb');
const logger = require('../utils/logger');

class TronService {
  constructor() {
    this.network = process.env.TRON_NETWORK || 'mainnet';
    this.usdtContract = this.network === 'mainnet' 
      ? 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'  // Mainnet USDT
      : 'TXYZopYRdj2D9XRtbG411XZZ3kM5VkAeBf';  // Testnet USDT

    this.tronWeb = new TronWeb({
      fullHost: this.network === 'mainnet' 
        ? 'https://api.tronstack.io'
        : 'https://api.shasta.trongrid.io',
      headers: { 'TRON-PRO-API-KEY': process.env.TRON_API_KEY },
    });

    logger.info(`✅ TRON servis başlatıldı: ${this.network}`);
  }

  getAddressFromPrivateKey(privateKey) {
    try {
      const tempTronWeb = new TronWeb({
        fullHost: this.network === "mainnet" ? "https://api.tronstack.io" : "https://api.shasta.trongrid.io",
        headers: { "TRON-PRO-API-KEY": process.env.TRON_API_KEY },
        privateKey: privateKey
      });
      
      return tempTronWeb.address.fromPrivateKey(privateKey);
    } catch (error) {
      throw new Error(`Invalid private key: ${error.message}`);
    }
  }

      async getBalance(address) {
    try {
      // TRX Balance
      const trxRaw = await this.tronWeb.trx.getBalance(address);
      const trxBalance = parseFloat(this.tronWeb.fromSun(trxRaw));
      
      // USDT Balance - contract çağrısı için geçici TronWeb instance
      let usdtBalance = 0;
      try {
        // Geçici private key ile TronWeb instance (sadece okuma için)
        const tempTronWeb = new TronWeb({
          fullHost: this.network === 'mainnet' 
            ? 'https://api.trongrid.io'
            : 'https://api.shasta.trongrid.io',
          headers: { 'TRON-PRO-API-KEY': process.env.TRON_API_KEY },
          privateKey: '01'.repeat(32) // Dummy private key sadece okuma için
        });
        
        const usdtContract = await tempTronWeb.contract().at(this.usdtContract);
        const usdtRaw = await usdtContract.balanceOf(address).call();
        
        if (usdtRaw && usdtRaw._hex) {
          // BigNumber format'ından normal sayıya çevir
          const usdtSun = tempTronWeb.toBigNumber(usdtRaw).toString();
          usdtBalance = parseFloat(usdtSun) / 1000000;
        } else if (usdtRaw) {
          usdtBalance = parseFloat(tempTronWeb.fromSun(usdtRaw)) / 1000000;
        }
        
      } catch (usdtError) {
        logger.error(`USDT balance error: ${usdtError.message}`);
        usdtBalance = 0;
      }
      
      logger.info(`Balance check - Address: ${address.substring(0, 8)}... TRX: ${trxBalance}, USDT: ${usdtBalance}`);
      
      return {
        trx: trxBalance,
        usdt: usdtBalance,
        address: address
      };
      
    } catch (error) {
      logger.error(`Get balance error for ${address}:`, error.message);
      return {
        trx: 0,
        usdt: 0,
        address: address,
        error: error.message
      };
    }
  }

  startConfirmationMonitoring(txHash, telegramId, amount, fromAddress, toAddress, sendUpdateCallback) {
    const maxAttempts = 8;
    let attempts = 0;

    const checkConfirmation = async () => {
      attempts++;
      logger.info(`Confirmation check #${attempts} for ${txHash}`);

      try {
        const txDetails = await this.getTransactionDetails(txHash);

        if (txDetails.confirmed && txDetails.success) {
          logger.info(`✅ Transaction SUCCESSFUL: ${txHash}, Fee: ${txDetails.fee} TRX`);
          
          await sendUpdateCallback(telegramId, {
            txHash,
            success: true,
            fee: txDetails.fee,
            energyUsed: txDetails.energyUsed,
            blockNumber: txDetails.blockNumber,
            amount,
            fromAddress,
            toAddress,
            result: txDetails.result
          });
          
          return;
          
        } else if (txDetails.confirmed && !txDetails.success) {
          logger.warn(`❌ Transaction FAILED: ${txHash}, Result: ${txDetails.result}`);
          
          await sendUpdateCallback(telegramId, {
            txHash,
            success: false,
            result: txDetails.result,
            amount,
            fromAddress,
            toAddress,
            fee: txDetails.fee || 0
          });
          
          return;
          
        } else if (txDetails.exists && !txDetails.confirmed) {
          logger.info(`Transaction exists but not confirmed yet: ${txHash}`);
          
        } else if (!txDetails.exists) {
          logger.info(`Transaction not yet on blockchain: ${txHash}`);
        }
        
        if (attempts < maxAttempts) {
          setTimeout(checkConfirmation, 30000);
        } else {
          logger.warn(`Transaction confirmation timeout: ${txHash} - NO NOTIFICATION SENT`);
        }
        
      } catch (error) {
        logger.error(`Confirmation check error for ${txHash}:`, error.message);
        
        if (attempts < maxAttempts) {
          setTimeout(checkConfirmation, 30000);
        } else {
          logger.error(`Final confirmation check failed for ${txHash}`);
        }
      }
    };

    setTimeout(checkConfirmation, 30000);
  }

  async getTransactionDetails(txHash) {
    try {
      const transaction = await this.tronWeb.trx.getTransaction(txHash);
      if (!transaction) {
        return { exists: false };
      }

      const transactionInfo = await this.tronWeb.trx.getTransactionInfo(txHash);
      
      if (!transactionInfo || !transactionInfo.id) {
        return { exists: true, confirmed: false, txHash: txHash };
      }

      const fee = transactionInfo.fee ? this.tronWeb.fromSun(transactionInfo.fee) : 0;
      const energyUsed = transactionInfo.receipt?.energy_usage_total || 0;
      const result = transactionInfo.result || 'SUCCESS';
      const success = result === 'SUCCESS';
      
      logger.info(`Transaction ${txHash}: Result=${result}, Fee=${fee} TRX`);
      
      return {
        exists: true,
        confirmed: true,
        success: success,
        result: result,
        fee: parseFloat(fee),
        energyUsed: energyUsed,
        blockNumber: transactionInfo.blockNumber || 0,
        txHash: txHash
      };

    } catch (error) {
      logger.error(`Transaction details error for ${txHash}:`, error.message);
      return { exists: false, error: error.message };
    }
  }

  async sendUsdt(fromPrivateKey, toAddress, amount, telegramId, sendUpdateCallback) {
    try {
      logger.info(`USDT transfer başlatıyor: ${amount} USDT -> ${toAddress}`);

      const tempTronWeb = new TronWeb({
        fullHost: this.network === 'mainnet' 
          ? 'https://api.tronstack.io'
          : 'https://api.shasta.trongrid.io',
        headers: { 'TRON-PRO-API-KEY': process.env.TRON_API_KEY },
        privateKey: fromPrivateKey
      });

      const fromAddress = tempTronWeb.address.fromPrivateKey(fromPrivateKey);
      logger.info(`Gönderen adres: ${fromAddress}`);

      const originalAmount = parseFloat(amount);
      const usdtSunAmount = originalAmount * 1000000;
      
      logger.info(`Original: ${originalAmount}, Float: ${parseFloat(amount)}, Sun: ${usdtSunAmount}`);

      const contract = await tempTronWeb.contract().at(this.usdtContract);
      logger.info('Contract yüklendi');

      logger.info('Transfer işlemi gönderiliyor...');
      const transaction = await contract.transfer(toAddress, usdtSunAmount).send();

      const txHash = transaction;
      logger.info(`Transaction broadcast edildi. Hash: ${txHash}`);

      this.startConfirmationMonitoring(txHash, telegramId, amount, fromAddress, toAddress, sendUpdateCallback);

      return {
        txHash: txHash,
        from: fromAddress,
        to: toAddress,
        amount: parseFloat(amount),
        status: 'broadcast',
        monitoring: true
      };

    } catch (error) {
      logger.error('❌ USDT transfer detaylı hatası:', {
        message: error.message,
        stack: error.stack,
        amount: amount,
        toAddress: toAddress
      });
      
      if (error.message.includes('insufficient balance')) {
        throw new Error('Yetersiz TRX bakiyesi (işlem ücreti için)');
      } else if (error.message.includes('REVERT opcode executed')) {
        throw new Error('Yetersiz USDT bakiyesi');
      } else if (error.message.includes('Contract validate error')) {
        throw new Error('Contract hatası - Yetersiz bakiye olabilir');
      } else if (error.message.includes('balance is not sufficient')) {
        throw new Error('Yetersiz USDT bakiyesi');
      } else {
        throw new Error(`İşlem başarısız: ${error.message}`);
      }
    }
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
