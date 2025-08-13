#!/bin/bash
echo "🔧 TronScan Result:Successful kontrolü ekleniyor..."

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

  // Detaylı transaction info al - TronScan sonucu kontrol et
  async getDetailedTransactionInfo(txHash) {
    try {
      // Önce transaction'ın var olup olmadığını kontrol et
      const transaction = await this.tronWeb.trx.getTransaction(txHash);
      if (!transaction || !transaction.txID) {
        logger.warn(`Transaction not found: ${txHash}`);
        return { exists: false };
      }

      // Transaction info al
      const txInfo = await this.tronWeb.trx.getTransactionInfo(txHash);
      if (!txInfo || !txInfo.id) {
        logger.warn(`Transaction info not ready: ${txHash}`);
        return { exists: true, confirmed: false };
      }

      // Result kontrolü - TronScan'daki "Result" field
      const result = txInfo.result; // "SUCCESS", "FAILED", "OUT_OF_TIME", etc.
      const contractResult = txInfo.contractResult; // Contract çağrısının sonucu
      
      // Fee hesapla
      const fee = txInfo.fee ? this.tronWeb.fromSun(txInfo.fee) : 0;
      const energyUsed = txInfo.receipt?.energy_usage_total || 0;
      const energyFee = txInfo.receipt?.energy_fee || 0;
      const netFee = txInfo.receipt?.net_fee || 0;
      
      // Toplam fee (energy + net + other fees)
      const totalFee = parseFloat(fee);

      logger.info(`Transaction ${txHash}: Result=${result}, Fee=${totalFee} TRX`);

      return {
        exists: true,
        confirmed: true,
        success: result === 'SUCCESS', // TronScan'daki "Result: Successful" kontrolü
        result: result,
        contractResult: contractResult,
        fee: totalFee,
        energyUsed: energyUsed,
        energyFee: this.tronWeb.fromSun(energyFee || 0),
        netFee: this.tronWeb.fromSun(netFee || 0),
        blockNumber: txInfo.blockNumber,
        blockTimeStamp: txInfo.blockTimeStamp,
        txInfo: txInfo // Debug için
      };

    } catch (error) {
      logger.error(`Transaction info error for ${txHash}:`, error.message);
      return { 
        exists: false, 
        error: error.message 
      };
    }
  }

  // Arka plan confirmation checker - SADECE SUCCESS kontrolü
  async startConfirmationMonitoring(txHash, telegramId, amount, fromAddress, toAddress, sendUpdateCallback) {
    const maxAttempts = 40; // 40 * 3 = 120 saniye
    let attempts = 0;

    const checkConfirmation = async () => {
      try {
        attempts++;
        logger.info(`Confirmation check #${attempts} for ${txHash}`);

        const txDetails = await this.getDetailedTransactionInfo(txHash);
        
        if (txDetails.confirmed && txDetails.success) {
          // ✅ Transaction SUCCESSFUL - Mesaj gönder!
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
          
          return; // Monitoring'i bitir
          
        } else if (txDetails.confirmed && !txDetails.success) {
          // ❌ Transaction FAILED - Hata mesajı gönder
          logger.warn(`❌ Transaction FAILED: ${txHash}, Result: ${txDetails.result}`);
          
          await sendUpdateCallback(telegramId, {
            txHash,
            success: false,
            failed: true,
            result: txDetails.result,
            amount,
            fromAddress,
            toAddress,
            fee: txDetails.fee || 0
          });
          
          return; // Monitoring'i bitir
          
        } else if (txDetails.exists && !txDetails.confirmed) {
          // Transaction var ama henüz confirm olmamış - bekle
          logger.info(`Transaction exists but not confirmed yet: ${txHash}`);
          
        } else if (!txDetails.exists) {
          // Transaction henüz blockchain'de görünmüyor - bekle
          logger.info(`Transaction not yet on blockchain: ${txHash}`);
        }
        
        // Henüz confirm olmamış veya başarısız değil - devam et
        if (attempts < maxAttempts) {
          setTimeout(checkConfirmation, 3000); // 3 saniye sonra tekrar dene
        } else {
          // Timeout - sadece bilgi mesajı, notification yok
          logger.warn(`Transaction confirmation timeout: ${txHash} - NO NOTIFICATION SENT`);
          // Timeout'da mesaj gönderme - kullanıcı TronScan'de kontrol etsin
        }
        
      } catch (error) {
        logger.error(`Confirmation check error for ${txHash}:`, error.message);
        
        if (attempts < maxAttempts) {
          setTimeout(checkConfirmation, 3000);
        } else {
          logger.error(`Final confirmation check failed for ${txHash}`);
          // Hata'da da mesaj gönderme
        }
      }
    };

    // İlk check'i başlat - 10 saniye sonra (transaction'ın propagate olması için)
    setTimeout(checkConfirmation, 10000);
  }

  async sendUsdt(fromPrivateKey, toAddress, amount, telegramId, sendUpdateCallback) {
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

      // Basit integer çarpma (6 decimal için)
      const amountFloat = parseFloat(amount);
      const amountInSun = Math.floor(amountFloat * 1000000);
      
      logger.info(`Original: ${amount}, Float: ${amountFloat}, Sun: ${amountInSun}`);

      // Contract instance
      const contract = await tempTronWeb.contract().at(this.usdtContractAddress);
      logger.info('Contract yüklendi');

      // Adres kontrolü
      if (!tempTronWeb.isAddress(toAddress)) {
        throw new Error('Geçersiz hedef adres');
      }

      // Transfer işlemi - broadcast
      logger.info('Transfer işlemi gönderiliyor...');
      
      const transaction = await contract.transfer(toAddress, amountInSun).send({
        feeLimit: 50000000, // 50 TRX
        callValue: 0,
        shouldPollResponse: false
      });

      // Transaction hash'i çıkar
      let txHash = '';
      
      if (typeof transaction === 'string') {
        txHash = transaction;
      } else if (transaction && transaction.txid) {
        txHash = transaction.txid;
      } else if (transaction && transaction.transaction && transaction.transaction.txID) {
        txHash = transaction.transaction.txID;
      } else if (transaction && transaction.transactionHash) {
        txHash = transaction.transactionHash;
      } else {
        logger.warn('Transaction formatı:', transaction);
        throw new Error('Transaction hash alınamadı');
      }

      logger.info(`Transaction broadcast edildi. Hash: ${txHash}`);

      // Arka planda confirmation monitoring başlat - SADECE SUCCESS için notification
      this.startConfirmationMonitoring(txHash, telegramId, amount, fromAddress, toAddress, sendUpdateCallback);

      // Hemen hash'i döndür
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
      
      // Hata türüne göre mesajlar
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

echo "✅ TronScan Result:Successful kontrolü eklendi!"
