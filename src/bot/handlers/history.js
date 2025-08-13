const { Markup } = require('telegraf');
const db = require('../../database');
const logger = require('../../utils/logger');
const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

class HistoryHandlers {
  static transactionHistory() {
    return async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        
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
          await ctx.reply('📭 **Henüz hiç işlem yapmadınız.**\n\n💡 İlk transferinizi yapmak için /send komutunu kullanın.');
          return;
        }

        // Telegram mesajı için ilk 20 işlemi göster
        const displayTransactions = transactions.slice(0, 20);
        let message = `📊 **İşlem Geçmişi** (Son ${displayTransactions.length})\n\n`;

        displayTransactions.forEach((tx, index) => {
          const date = new Date(tx.created_at).toLocaleString('tr-TR');
          const status = this.getStatusEmoji(tx.status);
          const shortHash = tx.tx_hash ? tx.tx_hash.substring(0, 8) + '...' : 'N/A';
          const shortTo = tx.to_address.substring(0, 8) + '...';

          message += `**${index + 1}.** ${status} ${tx.amount} USDT\n`;
          message += `   📥 Alıcı: \`${shortTo}\`\n`;
          message += `   📅 ${date}\n`;
          if (tx.tx_hash) {
            message += `   🔗 \`${shortHash}\`\n`;
          }
          message += '\n';
        });

        message += `\n📄 **PDF Raporu için butona tıklayın** (Son 50 işlem)`;

        const keyboard = Markup.inlineKeyboard([
          [
            Markup.button.callback('📄 PDF İndir (50 İşlem)', 'download_pdf'),
            Markup.button.callback('📊 Excel İndir', 'download_excel')
          ],
          [
            Markup.button.callback('✅ Başarılı', 'history_success'),
            Markup.button.callback('❌ Başarısız', 'history_failed'),
            Markup.button.callback('⏳ Bekleyen', 'history_pending')
          ],
          [
            Markup.button.callback('📈 Bu Hafta', 'history_week'),
            Markup.button.callback('📅 Bu Ay', 'history_month')
          ],
          [Markup.button.callback('🔄 Yenile', 'history_refresh')]
        ]);

        await ctx.reply(message, {
          parse_mode: 'Markdown',
          reply_markup: keyboard
        });

        // PDF callback handler ekle
        ctx.telegram.on('callback_query', async (query) => {
          if (query.data === 'download_pdf') {
            await this.generatePDF(ctx, transactions);
          }
        });

      } catch (error) {
        logger.error('Transaction history error:', error);
        await ctx.reply('❌ İşlem geçmişi yüklenemedi.');
      }
    };
  }

  static async generatePDF(ctx, transactions) {
    try {
      const doc = new PDFDocument({ 
        margin: 50,
        size: 'A4'
      });
      
      const fileName = `transactions_${Date.now()}.pdf`;
      const filePath = path.join('/tmp', fileName);
      const stream = fs.createWriteStream(filePath);
      
      doc.pipe(stream);

      // Header
      doc.fontSize(20)
         .font('Helvetica-Bold')
         .text('CRYPTO BOT - İŞLEM GEÇMİŞİ RAPORU', { align: 'center' });
      
      doc.moveDown();
      
      // Tarih bilgisi
      doc.fontSize(10)
         .font('Helvetica')
         .text(`Rapor Tarihi: ${new Date().toLocaleString('tr-TR')}`, { align: 'right' });
      
      doc.text(`Toplam İşlem: ${transactions.length}`, { align: 'right' });
      
      doc.moveDown();
      
      // Tablo başlıkları
      const tableTop = 150;
      const tableLeft = 50;
      const rowHeight = 25;
      
      // Başlık satırı - arka plan rengi
      doc.rect(tableLeft, tableTop, 500, rowHeight)
         .fillAndStroke('#f0f0f0', '#cccccc');
      
      // Başlıklar
      doc.fillColor('black')
         .fontSize(9)
         .font('Helvetica-Bold');
      
      doc.text('#', tableLeft + 5, tableTop + 8, { width: 25 });
      doc.text('Tarih/Saat', tableLeft + 35, tableTop + 8, { width: 90 });
      doc.text('Alıcı Adresi', tableLeft + 130, tableTop + 8, { width: 140 });
      doc.text('Miktar', tableLeft + 275, tableTop + 8, { width: 70 });
      doc.text('Durum', tableLeft + 350, tableTop + 8, { width: 50 });
      doc.text('TX Hash', tableLeft + 405, tableTop + 8, { width: 95 });
      
      // Tablodaki satırlar
      let yPosition = tableTop + rowHeight;
      
      doc.font('Helvetica')
         .fontSize(8);
      
      transactions.forEach((tx, index) => {
        // Yeni sayfa kontrolü
        if (yPosition > 700) {
          doc.addPage();
          yPosition = 50;
          
          // Yeni sayfada başlıkları tekrarla
          doc.rect(tableLeft, yPosition, 500, rowHeight)
             .fillAndStroke('#f0f0f0', '#cccccc');
          
          doc.fillColor('black')
             .fontSize(9)
             .font('Helvetica-Bold');
          
          doc.text('#', tableLeft + 5, yPosition + 8, { width: 25 });
          doc.text('Tarih/Saat', tableLeft + 35, yPosition + 8, { width: 90 });
          doc.text('Alıcı Adresi', tableLeft + 130, yPosition + 8, { width: 140 });
          doc.text('Miktar', tableLeft + 275, yPosition + 8, { width: 70 });
          doc.text('Durum', tableLeft + 350, yPosition + 8, { width: 50 });
          doc.text('TX Hash', tableLeft + 405, yPosition + 8, { width: 95 });
          
          yPosition += rowHeight;
          doc.font('Helvetica').fontSize(8);
        }
        
        // Satır arka planı (çift satırlar için)
        if (index % 2 === 0) {
          doc.rect(tableLeft, yPosition, 500, rowHeight)
             .fill('#f9f9f9');
        }
        
        // Satır çerçevesi
        doc.rect(tableLeft, yPosition, 500, rowHeight)
           .stroke('#e0e0e0');
        
        // Veri yazdırma
        doc.fillColor('black');
        
        const date = new Date(tx.created_at).toLocaleString('tr-TR', {
          day: '2-digit',
          month: '2-digit', 
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit'
        });
        
        const shortAddress = tx.to_address.substring(0, 8) + '...' + tx.to_address.substring(tx.to_address.length - 6);
        const txHash = tx.tx_hash ? tx.tx_hash.substring(0, 10) + '...' : 'N/A';
        const statusText = this.getStatusText(tx.status);
        const statusColor = this.getStatusColor(tx.status);
        
        doc.text(String(index + 1), tableLeft + 5, yPosition + 8, { width: 25 });
        doc.text(date, tableLeft + 35, yPosition + 8, { width: 90 });
        doc.text(shortAddress, tableLeft + 130, yPosition + 8, { width: 140 });
        doc.text(`${tx.amount} USDT`, tableLeft + 275, yPosition + 8, { width: 70 });
        
        // Durum renkli
        doc.fillColor(statusColor);
        doc.text(statusText, tableLeft + 350, yPosition + 8, { width: 50 });
        
        // TX Hash
        doc.fillColor('black');
        doc.text(txHash, tableLeft + 405, yPosition + 8, { width: 95 });
        
        yPosition += rowHeight;
      });
      
      // Özet bilgiler
      doc.moveDown(2);
      doc.fontSize(10)
         .font('Helvetica-Bold')
         .fillColor('black');
      
      const totalAmount = transactions.reduce((sum, tx) => sum + parseFloat(tx.amount || 0), 0);
      const successCount = transactions.filter(tx => tx.status === 'confirmed').length;
      const failedCount = transactions.filter(tx => tx.status === 'failed').length;
      const pendingCount = transactions.filter(tx => tx.status === 'pending' || tx.status === 'broadcast').length;
      
      doc.text('ÖZET BİLGİLER', { underline: true });
      doc.moveDown(0.5);
      doc.fontSize(9)
         .font('Helvetica');
      
      doc.text(`Toplam Transfer Miktarı: ${totalAmount.toFixed(2)} USDT`);
      doc.text(`Başarılı İşlemler: ${successCount}`);
      doc.text(`Başarısız İşlemler: ${failedCount}`);
      doc.text(`Bekleyen İşlemler: ${pendingCount}`);
      
      // Footer
      doc.fontSize(8)
         .fillColor('#666666')
         .text('Bu rapor Crypto Bot tarafından otomatik olarak oluşturulmuştur.', 
               50, doc.page.height - 50, 
               { align: 'center' });
      
      doc.end();
      
      // PDF oluşturulduktan sonra gönder
      stream.on('finish', async () => {
        await ctx.replyWithDocument(
          { source: filePath, filename: `islem_raporu_${new Date().toISOString().split('T')[0]}.pdf` },
          { caption: '📄 Son 50 işleminizin detaylı PDF raporu' }
        );
        
        // Geçici dosyayı sil
        fs.unlinkSync(filePath);
      });
      
    } catch (error) {
      logger.error('PDF generation error:', error);
      await ctx.reply('❌ PDF oluşturulurken hata oluştu.');
    }
  }

  static getStatusEmoji(status) {
    switch (status) {
      case 'confirmed': return '✅';
      case 'failed': return '❌';
      case 'pending': return '⏳';
      case 'broadcast': return '📡';
      default: return '❓';
    }
  }

  static getStatusText(status) {
    switch (status) {
      case 'confirmed': return 'Başarılı';
      case 'failed': return 'Başarısız';
      case 'pending': return 'Bekliyor';
      case 'broadcast': return 'İşleniyor';
      default: return 'Bilinmiyor';
    }
  }

  static getStatusColor(status) {
    switch (status) {
      case 'confirmed': return '#00a000';
      case 'failed': return '#ff0000';
      case 'pending': return '#ff9900';
      case 'broadcast': return '#0066cc';
      default: return '#666666';
    }
  }
}

module.exports = HistoryHandlers;