#!/bin/bash
echo "🔧 Şifreleme sistemi düzeltiliyor..."

# Yeni encryption.js oluştur
cat > src/security/encryption.js << 'ENCEOF'
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

class EncryptionService {
  constructor() {
    this.algorithm = 'aes-256-gcm';
    this.keyLength = 32;
    this.ivLength = 16;
    this.tagLength = 16;
    this.saltLength = 64;
  }

  deriveKey(password, salt) {
    return crypto.pbkdf2Sync(password, salt, 100000, this.keyLength, 'sha512');
  }

  encryptPrivateKey(privateKey, masterPassword) {
    try {
      const salt = crypto.randomBytes(this.saltLength);
      const iv = crypto.randomBytes(this.ivLength);
      const key = this.deriveKey(masterPassword, salt);
      
      const cipher = crypto.createCipherGCM(this.algorithm, key, iv);
      
      let encrypted = cipher.update(privateKey, 'utf8', 'hex');
      encrypted += cipher.final('hex');
      
      const tag = cipher.getAuthTag();
      
      return {
        encrypted,
        salt: salt.toString('hex'),
        iv: iv.toString('hex'),
        tag: tag.toString('hex')
      };
    } catch (error) {
      logger.error('Private key encryption failed:', error);
      throw new Error('Şifreleme başarısız');
    }
  }

  decryptPrivateKey(encryptedData, masterPassword) {
    try {
      const { encrypted, salt, iv, tag } = encryptedData;
      const key = this.deriveKey(masterPassword, Buffer.from(salt, 'hex'));
      
      const decipher = crypto.createDecipherGCM(this.algorithm, key, Buffer.from(iv, 'hex'));
      decipher.setAuthTag(Buffer.from(tag, 'hex'));
      
      let decrypted = decipher.update(encrypted, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      
      return decrypted;
    } catch (error) {
      logger.error('Private key decryption failed:', error);
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
ENCEOF

echo "✅ Şifreleme sistemi düzeltildi!"
