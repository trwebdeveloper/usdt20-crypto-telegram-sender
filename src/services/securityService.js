const crypto = require('crypto');
const logger = require('../utils/logger');

class SecurityService {
  encryptPrivateKey(privateKey, masterPassword) {
    try {
      const salt = crypto.randomBytes(16);
      const key = crypto.pbkdf2Sync(masterPassword, salt, 100000, 32, 'sha512');
      const iv = crypto.randomBytes(16);
      
      const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
      const encrypted = cipher.update(privateKey, 'utf8', 'hex') + cipher.final('hex');
      const authTag = cipher.getAuthTag();
      
      return salt.toString('hex') + ':' + iv.toString('hex') + ':' + authTag.toString('hex') + ':' + encrypted;
    } catch (error) {
      logger.error('Encrypt private key error:', error);
      throw new Error('Şifreleme hatası');
    }
  }

  decryptPrivateKey(encryptedPrivateKey, masterPassword) {
    try {
      const parts = encryptedPrivateKey.split(':');
      
      // Yeni format (4 parça: salt:iv:authTag:encrypted)
      if (parts.length === 4) {
        const salt = Buffer.from(parts[0], 'hex');
        const iv = Buffer.from(parts[1], 'hex');
        const authTag = Buffer.from(parts[2], 'hex');
        const encrypted = parts[3];

        const key = crypto.pbkdf2Sync(masterPassword, salt, 100000, 32, 'sha512');
        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(authTag);

        const decrypted = decipher.update(encrypted, 'hex', 'utf8') + decipher.final('utf8');
        return decrypted;
      }
      
      // Eski format (3 parça: salt:authTag:encrypted) - deprecated method
      else if (parts.length === 3) {
        logger.warn('Using deprecated encryption format - please re-add wallet');
        const salt = Buffer.from(parts[0], 'hex');
        const authTag = Buffer.from(parts[1], 'hex');
        const encrypted = parts[2];

        const key = crypto.pbkdf2Sync(masterPassword, salt, 100000, 32, 'sha512');
        const decipher = crypto.createDecipher('aes-256-gcm', key);
        decipher.setAuthTag(authTag);

        const decrypted = decipher.update(encrypted, 'hex', 'utf8') + decipher.final('utf8');
        return decrypted;
      }
      
      else {
        throw new Error('Geçersiz şifreli veri formatı');
      }

    } catch (error) {
      logger.error('Decrypt private key error:', error);
      throw new Error('Yanlış master şifre veya bozuk veri');
    }
  }
}

module.exports = new SecurityService();
