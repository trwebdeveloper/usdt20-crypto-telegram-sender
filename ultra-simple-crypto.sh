#!/bin/bash
echo "⚡ Ultra basit şifreleme..."

cat > src/security/encryption.js << 'SIMPLEEOF'
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const logger = require('../utils/logger');

class EncryptionService {
  constructor() {
    this.algorithm = 'aes-256-cbc';
  }

  encryptPrivateKey(privateKey, masterPassword) {
    try {
      const iv = crypto.randomBytes(16);
      const salt = crypto.randomBytes(32);
      const key = crypto.pbkdf2Sync(masterPassword, salt, 1000, 32, 'sha256');
      
      const cipher = crypto.createCipheriv(this.algorithm, key, iv);
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
      const key = crypto.pbkdf2Sync(masterPassword, Buffer.from(salt, 'hex'), 1000, 32, 'sha256');
      
      const decipher = crypto.createDecipheriv(this.algorithm, key, Buffer.from(iv, 'hex'));
      let decrypted = decipher.update(encrypted, 'hex', 'utf8');
      decrypted += decipher.final('utf8');
      
      return decrypted;
    } catch (error) {
      logger.error('Decryption error:', error);
      throw new Error('Şifre çözme başarısız');
    }
  }

  async hashPassword(password) {
    return bcrypt.hash(password, 12);
  }

  async verifyPassword(password, hash) {
    return bcrypt.compare(password, hash);
  }

  generateSecureRandom(length = 32) {
    return crypto.randomBytes(length).toString('hex');
  }
}

module.exports = new EncryptionService();
SIMPLEEOF

echo "✅ Ultra basit şifreleme oluşturuldu!"
