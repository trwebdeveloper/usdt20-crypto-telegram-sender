#!/bin/bash
echo "🔧 Wallet service ve send handler asenkron güncelle..."

# Wallet service'i güncelle - sendUsdt fonksiyonu
cat > temp_wallet_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/blockchain/wallet.js', 'utf8');

// sendUsdt fonksiyonunu bul ve güncelle
const oldSendUsdt = /async sendUsdt\(telegramId, walletId, toAddress, amount, masterPassword\) \{[\s\S]*?return result;[\s\S]*?\}/;

const newSendUsdt = `async sendUsdt(telegramId, walletId, toAddress, amount, masterPassword, sendUpdateCallback) {
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

      logger.info(\`USDT transfer başlatıldı: \${amount} USDT \${wallet.address} -> \${toAddress}\`);

      return result;

    } catch (error) {
      logger.error('Transfer hatası:', error);
      throw error;
    }
  }`;

content = content.replace(oldSendUsdt, newSendUsdt);

fs.writeFileSync('src/blockchain/wallet.js', content);
console.log('✅ Wallet service async güncellendi!');
TEMPEOF

node temp_wallet_fix.js
rm temp_wallet_fix.js

echo "✅ Async sistemler hazırlandı!"
