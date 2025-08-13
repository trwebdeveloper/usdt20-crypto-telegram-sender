#!/bin/bash
echo "🔧 İlk mesajı sadeleştirip confirmation mesajını detaylandırıyor..."

cat > temp_send_handler_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/bot/handlers/send.js', 'utf8');

// İlk mesajı sadeleştir (broadcast mesajı)
const oldInitialMessage = /const initialMessage = `📤 \*İşlem Blockchain'e Gönderildi!\*[\s\S]*?🔍 TronScan: https:\/\/tronscan\.org\/#\/transaction\/\${result\.txHash}`;/;

const newInitialMessage = `const initialMessage = \`📤 **İşlem Blockchain'e Gönderildi!**

🔗 **Transaction Hash:**
\\\`\${result.txHash}\\\`

⏳ Confirmation bekleniyor...\`;`;

content = content.replace(oldInitialMessage, newInitialMessage);

// Confirmation callback'indeki success mesajını detaylandır
const oldSuccessMessage = /if \(confirmationData\.success\) \{[\s\S]*?🎉 USDT başarıyla gönderildi!\`;/;

const newSuccessMessage = `if (confirmationData.success) {
          // Başarılı işlem - DETAYLI MESAJ
          message = \`✅ **İşlem Başarıyla Tamamlandı!**

🔗 **Transaction Hash:**
\\\`\${confirmationData.txHash}\\\`

📊 **İşlem Detayları:**
💰 Miktar: \${confirmationData.amount} USDT
📤 Gönderen: \\\`\${confirmationData.fromAddress.substring(0, 8)}...\\\`
📥 Alıcı: \\\`\${confirmationData.toAddress.substring(0, 8)}...\\\`
📅 Zaman: \${new Date().toLocaleString('tr-TR')}

💸 **Blockchain Bilgileri:**
⛽ Ödenen Fee: \${confirmationData.fee || 0} TRX
⚡ Energy Kullanılan: \${confirmationData.energyUsed || 0}
📦 Block Numarası: \${confirmationData.blockNumber || 'N/A'}
✅ Durum: \${confirmationData.result || 'SUCCESS'}

🔍 **TronScan'de Görüntüle:**
https://tronscan.org/#/transaction/\${confirmationData.txHash}

🎉 **USDT başarıyla gönderildi!**\`;`;

content = content.replace(oldSuccessMessage, newSuccessMessage);

// Failed mesajını da güncelle
const oldFailedMessage = /} else if \(confirmationData\.failed\) \{[\s\S]*?\`;/;

const newFailedMessage = `} else if (confirmationData.failed) {
          // Başarısız işlem
          message = \`❌ **İşlem Başarısız Oldu!**

🔗 **Transaction Hash:**
\\\`\${confirmationData.txHash}\\\`

📊 **İşlem Detayları:**
💰 Miktar: \${confirmationData.amount} USDT
📤 Gönderen: \\\`\${confirmationData.fromAddress.substring(0, 8)}...\\\`
📥 Alıcı: \\\`\${confirmationData.toAddress.substring(0, 8)}...\\\`
📅 Zaman: \${new Date().toLocaleString('tr-TR')}

❌ **Hata Bilgisi:**
🚫 Durum: \${confirmationData.result || 'FAILED'}
⛽ Harcanan Fee: \${confirmationData.fee || 0} TRX

🔍 **TronScan'de Görüntüle:**
https://tronscan.org/#/transaction/\${confirmationData.txHash}

💡 **Not:** İşlem başarısız oldu, USDT gönderilmedi.\`;`;

content = content.replace(oldFailedMessage, newFailedMessage);

fs.writeFileSync('src/bot/handlers/send.js', content);
console.log('✅ Mesaj formatları güncellendi!');
TEMPEOF

node temp_send_handler_fix.js
rm temp_send_handler_fix.js

echo "✅ İlk mesaj sadeleştirildi, confirmation mesajı detaylandırıldı!"
