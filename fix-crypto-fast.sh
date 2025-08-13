#!/bin/bash
echo "⚡ Hızlı şifreleme düzeltmesi..."

# Çalışan encryption.js dosyasını oluştur
cat > src/security/encryption.js << 'CRYPTOEOF'
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

class EncryptionService {
  constructor() {
    this.algorithm = 'aes-256-cbc';
    this.keyLength = 32;
    this.ivLength = 16;
    this.saltLength = 32;
  }

  deriveKey(password, salt) {
    return crypto.pbkdf2Sync(password, salt, 100000, this.keyLength, 'sha512');
  }

  encryptPrivateKey(privateKey, masterPassword) {
    try {
      const salt = crypto.randomBytes(this.saltLength);
      const iv = crypto.randomBytes(this.ivLength);
      const key = this.deriveKey(masterPassword, salt);
      
      const cipher = crypto.createCipher(this.algorithm, key);
      cipher.setIV(iv);
      
      let encrypted = cipher.update(privateKey, 'utf8', 'hex');
      encrypted += cipher.final('hex');
      
      return {
        encrypted,
        salt: salt.toString('hex'),
        iv: iv.toString('hex'),
        tag: ''
      };
    } catch (error) {
      logger.error('Encryption error:', error);
      throw new Error('Şifreleme başarısız');
    }
  }

  decryptPrivateKey(encryptedData, masterPassword) {
    try {
      const { encrypted, salt, iv } = encryptedData;
      const key = this.deriveKey(masterPassword, Buffer.from(salt, 'hex'));
      
      const decipher = crypto.createDecipher(this.algorithm, key);
      decipher.setIV(Buffer.from(iv, 'hex'));
      
      let decrypted = decipher.update(encrypted, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      
      return decrypted;
    } catch (error) {
      logger.error('Decryption error:', error);
      throw new Error('Şifre çözme başarısız');
    }
  }

  async hashPassword(password) {
    const saltRounds = parseInt(process.env.SALT_ROUNDS) || 12;
    return bcrypt.hash(password, saltRounds);
  }

  async verifyPassword(password, hash) {
    return bcrypt.compare(password, hash);
  }

  generateSecureRandom(length = 32) {
    return crypto.randomBytes(length).toString('hex');
  }
}

module.exports = new EncryptionService();
CRYPTOEOF

echo "✅ Şifreleme düzeltildi!"
echo "🧪 Test ediliyor..."

# Test et
node -e "
const enc = require('./src/security/encryption');
try {
  const test = enc.encryptPrivateKey('test123', 'pass123');
  const dec = enc.decryptPrivateKey(test, 'pass123');
  console.log('✅ Test başarılı:', dec === 'test123');
} catch(e) {
  console.log('❌ Test failed:', e.message);
}
" 2>/dev/null

echo "🚀 Bot'u yeniden başlatabilirsiniz!"
