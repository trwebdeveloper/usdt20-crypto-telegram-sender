const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');
const logger = require('../utils/logger');

class PdfService {
  constructor() {
    this.reportsDir = path.join(__dirname, '../../reports');
    if (!fs.existsSync(this.reportsDir)) {
      fs.mkdirSync(this.reportsDir, { recursive: true });
    }
  }

  async generateMultisendReport(telegramId, results, totalAmount) {
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `multisend_${telegramId}_${timestamp}.txt`;
      const filePath = path.join(this.reportsDir, fileName);

      const successCount = results.filter(r => r.success).length;
      const failedCount = results.filter(r => !r.success).length;

      const report = `
=====================================
         MULTISEND RAPORU
=====================================
📅 Tarih: ${new Date().toLocaleString('tr-TR')}
👤 Kullanıcı ID: ${telegramId}

📊 ÖZET BİLGİLER:
- Toplam İşlem: ${results.length}
- ✅ Başarılı: ${successCount}
- ❌ Başarısız: ${failedCount}
- 💰 Toplam Miktar: ${totalAmount} USDT

=====================================
                İŞLEMLER
=====================================

${results.map((result, index) => {
  const status = result.success ? '✅ BAŞARILI' : '❌ BAŞARISIZ';
  const error = result.error ? `\n     Hata: ${result.error}` : '';
  const hash = result.txHash ? `\n     TX: ${result.txHash}` : '';
  
  return `${index + 1}. ${status}
   📥 Hedef: ${result.toAddress}
   💰 Miktar: ${result.amount} USDT${hash}${error}`;
}).join('\n\n')}

=====================================
Bu rapor CryptoBot tarafından otomatik
olarak oluşturulmuştur.
${new Date().toLocaleString('tr-TR')}
=====================================
      `;

      fs.writeFileSync(filePath, report);

      return {
        success: true,
        fileName: fileName,
        filePath: filePath,
        size: fs.statSync(filePath).size
      };

    } catch (error) {
      logger.error('Rapor oluşturma hatası:', error);
      return { success: false, error: error.message };
    }
  }
}

module.exports = new PdfService();
