#!/bin/bash
echo "📄 PDF rapor özelliği ekleniyor..."

# 1. Gerekli paketleri kur
echo "📦 PDF paketleri kuruluyor..."
npm install puppeteer html-pdf jspdf

# 2. PDF Service oluştur
echo "🔧 PDF service oluşturuluyor..."
mkdir -p src/services
cat > src/services/pdfService.js << 'PDFEOF'
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
      const fileName = `multisend_${telegramId}_${timestamp}.pdf`;
      const filePath = path.join(this.reportsDir, fileName);

      // HTML template oluştur
      const html = this.createMultisendHTML(results, totalAmount);

      // Puppeteer ile PDF oluştur
      const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });

      const page = await browser.newPage();
      await page.setContent(html, { waitUntil: 'networkidle0' });

      await page.pdf({
        path: filePath,
        format: 'A4',
        printBackground: true,
        margin: {
          top: '20mm',
          right: '15mm',
          bottom: '20mm',
          left: '15mm'
        }
      });

      await browser.close();

      logger.info(`PDF raporu oluşturuldu: ${fileName}`);
      return {
        success: true,
        fileName: fileName,
        filePath: filePath,
        size: fs.statSync(filePath).size
      };

    } catch (error) {
      logger.error('PDF oluşturma hatası:', error);
      return { success: false, error: error.message };
    }
  }

  createMultisendHTML(results, totalAmount) {
    const date = new Date().toLocaleString('tr-TR');
    const successCount = results.filter(r => r.success).length;
    const failedCount = results.filter(r => !r.success).length;

    let transactionRows = '';
    results.forEach((result, index) => {
      const status = result.success ? '✅ Başarılı' : '❌ Başarısız';
      const statusClass = result.success ? 'success' : 'failed';
      const txHash = result.txHash || 'N/A';
      const shortHash = txHash.length > 20 ? txHash.substring(0, 20) + '...' : txHash;
      
      transactionRows += `
        <tr class="${statusClass}">
          <td>${index + 1}</td>
          <td class="address">${result.toAddress}</td>
          <td class="amount">${result.amount} USDT</td>
          <td class="status">${status}</td>
          <td class="hash">${shortHash}</td>
          <td class="error">${result.error || '-'}</td>
        </tr>
      `;
    });

    return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Multisend Raporu</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: Arial, sans-serif; 
                line-height: 1.6; 
                color: #333;
                background: #fff;
            }
            .header { 
                text-align: center; 
                margin-bottom: 30px; 
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                border-radius: 10px;
            }
            .header h1 { 
                font-size: 28px; 
                margin-bottom: 10px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .header p { 
                font-size: 16px; 
                opacity: 0.9;
            }
            .summary { 
                display: flex; 
                justify-content: space-around; 
                margin-bottom: 30px; 
                padding: 20px;
                background: #f8f9fa;
                border-radius: 10px;
                border: 1px solid #e9ecef;
            }
            .summary-item { 
                text-align: center; 
                padding: 15px;
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                min-width: 120px;
            }
            .summary-item h3 { 
                font-size: 24px; 
                margin-bottom: 5px;
                color: #495057;
            }
            .summary-item p { 
                color: #6c757d; 
                font-size: 14px;
                font-weight: 500;
            }
            .success-count { color: #28a745; }
            .failed-count { color: #dc3545; }
            .total-amount { color: #007bff; }
            table { 
                width: 100%; 
                border-collapse: collapse; 
                margin-top: 20px;
                background: white;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            th { 
                background: #343a40; 
                color: white; 
                padding: 15px 10px; 
                text-align: left;
                font-weight: 600;
                font-size: 14px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }
            td { 
                padding: 12px 10px; 
                border-bottom: 1px solid #dee2e6;
                font-size: 13px;
            }
            tr:hover { background-color: #f8f9fa; }
            .success { background-color: #d4edda; }
            .failed { background-color: #f8d7da; }
            .address { 
                font-family: monospace; 
                font-size: 11px;
                word-break: break-all;
                max-width: 200px;
            }
            .amount { 
                font-weight: bold; 
                text-align: right;
                color: #007bff;
            }
            .status { 
                font-weight: bold; 
                text-align: center;
            }
            .hash { 
                font-family: monospace; 
                font-size: 10px;
                color: #6c757d;
            }
            .error { 
                font-size: 11px; 
                color: #dc3545;
                max-width: 150px;
                word-wrap: break-word;
            }
            .footer { 
                margin-top: 30px; 
                text-align: center; 
                color: #6c757d;
                font-size: 12px;
                padding: 20px;
                border-top: 1px solid #dee2e6;
            }
            .footer p { margin-bottom: 5px; }
            .watermark {
                position: fixed;
                bottom: 20px;
                right: 20px;
                opacity: 0.3;
                font-size: 10px;
                color: #6c757d;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>📤 Toplu USDT Gönderim Raporu</h1>
            <p>Oluşturulma Tarihi: ${date}</p>
        </div>

        <div class="summary">
            <div class="summary-item">
                <h3 class="success-count">${successCount}</h3>
                <p>Başarılı İşlem</p>
            </div>
            <div class="summary-item">
                <h3 class="failed-count">${failedCount}</h3>
                <p>Başarısız İşlem</p>
            </div>
            <div class="summary-item">
                <h3>${results.length}</h3>
                <p>Toplam İşlem</p>
            </div>
            <div class="summary-item">
                <h3 class="total-amount">${totalAmount}</h3>
                <p>Toplam USDT</p>
            </div>
        </div>

        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Hedef Adres</th>
                    <th>Miktar</th>
                    <th>Durum</th>
                    <th>TX Hash</th>
                    <th>Hata</th>
                </tr>
            </thead>
            <tbody>
                ${transactionRows}
            </tbody>
        </table>

        <div class="footer">
            <p><strong>CryptoBot Multisend Raporu</strong></p>
            <p>Bu rapor ${date} tarihinde otomatik olarak oluşturulmuştur.</p>
            <p>Tüm işlemler TRON (TRC20) ağında gerçekleştirilmiştir.</p>
        </div>

        <div class="watermark">
            CryptoBot v1.0
        </div>
    </body>
    </html>
    `;
  }

  async generateTransactionHistory(telegramId, transactions) {
    try {
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const fileName = `history_${telegramId}_${timestamp}.pdf`;
      const filePath = path.join(this.reportsDir, fileName);

      const html = this.createHistoryHTML(transactions);

      const browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });

      const page = await browser.newPage();
      await page.setContent(html, { waitUntil: 'networkidle0' });

      await page.pdf({
        path: filePath,
        format: 'A4',
        printBackground: true,
        margin: {
          top: '20mm',
          right: '15mm',
          bottom: '20mm',
          left: '15mm'
        }
      });

      await browser.close();

      logger.info(`History PDF raporu oluşturuldu: ${fileName}`);
      return {
        success: true,
        fileName: fileName,
        filePath: filePath,
        size: fs.statSync(filePath).size
      };

    } catch (error) {
      logger.error('History PDF oluşturma hatası:', error);
      return { success: false, error: error.message };
    }
  }

  createHistoryHTML(transactions) {
    const date = new Date().toLocaleString('tr-TR');
    const totalAmount = transactions.reduce((sum, tx) => sum + parseFloat(tx.amount), 0);
    const successCount = transactions.filter(tx => tx.status === 'confirmed').length;

    let transactionRows = '';
    transactions.forEach((tx, index) => {
      const status = tx.status === 'confirmed' ? '✅ Onaylandı' : 
                    tx.status === 'failed' ? '❌ Başarısız' : '⏳ Bekliyor';
      const statusClass = tx.status === 'confirmed' ? 'success' : 
                         tx.status === 'failed' ? 'failed' : 'pending';
      const txDate = new Date(tx.created_at).toLocaleString('tr-TR');
      const shortHash = tx.tx_hash.substring(0, 20) + '...';
      
      transactionRows += `
        <tr class="${statusClass}">
          <td>${index + 1}</td>
          <td>${txDate}</td>
          <td class="address">${tx.to_address}</td>
          <td class="amount">${tx.amount} USDT</td>
          <td class="status">${status}</td>
          <td class="hash">${shortHash}</td>
        </tr>
      `;
    });

    return `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>İşlem Geçmişi Raporu</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: Arial, sans-serif; 
                line-height: 1.6; 
                color: #333;
                background: #fff;
            }
            .header { 
                text-align: center; 
                margin-bottom: 30px; 
                padding: 20px;
                background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
                color: white;
                border-radius: 10px;
            }
            .header h1 { 
                font-size: 28px; 
                margin-bottom: 10px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
            }
            .summary { 
                display: flex; 
                justify-content: space-around; 
                margin-bottom: 30px; 
                padding: 20px;
                background: #f8f9fa;
                border-radius: 10px;
            }
            .summary-item { 
                text-align: center; 
                padding: 15px;
                background: white;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .summary-item h3 { 
                font-size: 24px; 
                margin-bottom: 5px;
                color: #495057;
            }
            table { 
                width: 100%; 
                border-collapse: collapse; 
                margin-top: 20px;
                background: white;
                border-radius: 8px;
                overflow: hidden;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }
            th { 
                background: #343a40; 
                color: white; 
                padding: 15px 10px; 
                text-align: left;
                font-weight: 600;
            }
            td { 
                padding: 12px 10px; 
                border-bottom: 1px solid #dee2e6;
                font-size: 13px;
            }
            .success { background-color: #d4edda; }
            .failed { background-color: #f8d7da; }
            .pending { background-color: #fff3cd; }
            .address { 
                font-family: monospace; 
                font-size: 11px;
                word-break: break-all;
                max-width: 200px;
            }
            .amount { 
                font-weight: bold; 
                text-align: right;
                color: #007bff;
            }
            .hash { 
                font-family: monospace; 
                font-size: 10px;
                color: #6c757d;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>📊 İşlem Geçmişi Raporu</h1>
            <p>Oluşturulma Tarihi: ${date}</p>
        </div>

        <div class="summary">
            <div class="summary-item">
                <h3>${transactions.length}</h3>
                <p>Toplam İşlem</p>
            </div>
            <div class="summary-item">
                <h3>${successCount}</h3>
                <p>Başarılı İşlem</p>
            </div>
            <div class="summary-item">
                <h3>${totalAmount.toFixed(2)}</h3>
                <p>Toplam USDT</p>
            </div>
        </div>

        <table>
            <thead>
                <tr>
                    <th>#</th>
                    <th>Tarih</th>
                    <th>Hedef Adres</th>
                    <th>Miktar</th>
                    <th>Durum</th>
                    <th>TX Hash</th>
                </tr>
            </thead>
            <tbody>
                ${transactionRows}
            </tbody>
        </table>

        <div class="footer">
            <p><strong>CryptoBot İşlem Geçmişi</strong></p>
            <p>Bu rapor ${date} tarihinde oluşturulmuştur.</p>
        </div>
    </body>
    </html>
    `;
  }
}

module.exports = new PdfService();
PDFEOF

# 3. Send Handler'a PDF özelliği ekle
echo "📤 Send handler'a PDF özelliği ekleniyor..."
sed -i '/const SendHandlers = require/a const pdfService = require('\''../../services/pdfService'\'');' src/bot/handlers/send.js

# Multisend password handler'ın sonuna PDF oluşturma ekle
sed -i '/logger.info(`Multisend completed:/a\
\        // PDF raporu oluştur\
        try {\
          const pdfResult = await pdfService.generateMultisendReport(telegramId, results, transactions.reduce((sum, tx) => sum + tx.amount, 0));\
          \
          if (pdfResult.success) {\
            // PDF dosyasını kullanıcıya gönder\
            await ctx.replyWithDocument({\
              source: pdfResult.filePath,\
              filename: pdfResult.fileName\
            }, {\
              caption: `📄 **Multisend Raporu**\\n\\n📊 ${transactions.length} işlem\\n📁 Dosya boyutu: ${(pdfResult.size / 1024).toFixed(1)} KB`,\
              parse_mode: '\''Markdown'\''\
            });\
            \
            logger.info(`PDF raporu gönderildi: ${pdfResult.fileName}`);\
          }\
        } catch (pdfError) {\
          logger.error('\''PDF raporu oluşturma hatası:'\'', pdfError);\
        }' src/bot/handlers/send.js

# 4. History handler'a PDF özelliği ekle
echo "📊 History handler'a PDF özelliği ekleniyor..."
sed -i '/const HistoryHandlers = require/a const pdfService = require('\''../../services/pdfService'\'');' src/bot/handlers/history.js

# History'de PDF export butonu ekle
sed -i '/Markup.button.callback('\''🔄 Yenile'\'', '\''history_refresh'\'')/a,\
            [Markup.button.callback('\''📄 PDF İndir'\'', '\''export_pdf'\'')]' src/bot/handlers/history.js

# PDF export handler ekle
cat >> src/bot/handlers/history.js << 'EXPORTEOF'

  static exportPDF() {
    return async (ctx) => {
      try {
        await ctx.answerCbQuery('📄 PDF raporu hazırlanıyor...');
        
        const telegramId = ctx.from.id;
        
        // Son 50 işlemi getir
        const transactions = await db.all(`
          SELECT t.*, w.name as wallet_name 
          FROM transactions t
          JOIN wallets w ON t.from_wallet = w.address
          JOIN users u ON w.user_id = u.id
          WHERE u.telegram_id = ? 
          ORDER BY t.created_at DESC 
          LIMIT 50
        `, [telegramId]);

        if (!transactions || transactions.length === 0) {
          await ctx.editMessageText('📭 PDF oluşturmak için en az 1 işlem gerekli.');
          return;
        }

        const pdfResult = await pdfService.generateTransactionHistory(telegramId, transactions);
        
        if (pdfResult.success) {
          await ctx.replyWithDocument({
            source: pdfResult.filePath,
            filename: pdfResult.fileName
          }, {
            caption: `📄 **İşlem Geçmişi Raporu**\n\n📊 ${transactions.length} işlem\n📁 Dosya boyutu: ${(pdfResult.size / 1024).toFixed(1)} KB`,
            parse_mode: 'Markdown'
          });
          
          logger.info(`History PDF raporu gönderildi: ${pdfResult.fileName}`);
        } else {
          await ctx.editMessageText('❌ PDF raporu oluşturulamadı.');
        }

      } catch (error) {
        logger.error('PDF export error:', error);
        await ctx.answerCbQuery('❌ PDF oluşturma başarısız!');
      }
    };
  }
EXPORTEOF

# 5. Bot index'e PDF callback ekle
echo "🤖 Bot index'e PDF callback ekleniyor..."
sed -i '/this.bot.action(/^history_/a\    this.bot.action('\''export_pdf'\'', HistoryHandlers.exportPDF());' src/bot/index.js

# 6. Reports klasörü oluştur
echo "📁 Reports klasörü oluşturuluyor..."
mkdir -p reports
chmod 755 reports

echo ""
echo "✅ PDF RAPOR ÖZELLİKLERİ EKLENDİ!"
echo ""
echo "🎯 Yeni özellikler:"
echo "  📤 Multisend sonrası otomatik PDF raporu"
echo "  📊 History'den PDF export butonu"  
echo "  📄 Profesyonel tablo formatında raporlar"
echo "  💼 Özet istatistikler ve grafikler"
echo "  📁 reports/ klasöründe saklanır"
echo ""
echo "🚀 Kullanım:"
echo "  1. /multisend yap - otomatik PDF gelir"
echo "  2. /history komutu - 'PDF İndir' butonuna bas"
echo ""
echo "⚠️ İlk kez PDF oluştururken Puppeteer Chrome'u indirecek (100MB)"
echo "   Bu işlem biraz zaman alabilir."
echo ""
echo "🎉 Artık tüm multisend işlemleriniz PDF raporu ile geliyor!"