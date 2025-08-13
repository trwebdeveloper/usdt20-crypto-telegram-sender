#!/bin/bash
echo "🔧 Send handler fee bilgisi için güncelleniyor..."

# handleSendPassword fonksiyonundaki success message'ı güncelle
cat > temp_send_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/bot/handlers/send.js', 'utf8');

// Success message kısmını bul ve değiştir
const oldSuccessMessage = `const successMessage = \`✅ \*İşlem Başarıyla Gönderildi!\*

🔗 \*Transaction Hash:\*
\\\`\${result.txHash}\\\`

📊 \*Detaylar:\*
💰 Miktar: \${amount} USDT
📤 Gönderen: \\\`\${result.from.substring(0, 8)}...\\\`
📥 Alıcı: \\\`\${toAddress.substring(0, 8)}...\\\`
📅 Zaman: \${new Date().toLocaleString('tr-TR')}

⏳ İşlem ağda onaylanıyor...
/status komutu ile durumu takip edebilirsiniz.

🎉 Başarılı transfer!\`;`;

const newSuccessMessage = `let successMessage = '';
        
        if (result.status === 'confirmed') {
          successMessage = \`✅ \*İşlem Başarıyla Tamamlandı!\*

🔗 \*Transaction Hash:\*
\\\`\${result.txHash}\\\`

📊 \*Detaylar:\*
💰 Miktar: \${amount} USDT
📤 Gönderen: \\\`\${result.from.substring(0, 8)}...\\\`
📥 Alıcı: \\\`\${toAddress.substring(0, 8)}...\\\`
📅 Zaman: \${new Date().toLocaleString('tr-TR')}
⛽ Harcanan Fee: \${result.fee || 0} TRX
⚡ Energy: \${result.energyUsed || 0}
📦 Block: \${result.blockNumber || 'N/A'}

✅ İşlem blockchain'de onaylandı!
🔍 TronScan: https://tronscan.org/#/transaction/\${result.txHash}

🎉 Başarılı transfer!\`;
        } else {
          successMessage = \`✅ \*İşlem Gönderildi!\*

🔗 \*Transaction Hash:\*
\\\`\${result.txHash}\\\`

📊 \*Detaylar:\*
💰 Miktar: \${amount} USDT
📤 Gönderen: \\\`\${result.from.substring(0, 8)}...\\\`
📥 Alıcı: \\\`\${toAddress.substring(0, 8)}...\\\`
📅 Zaman: \${new Date().toLocaleString('tr-TR')}

⏳ İşlem ağda işleniyor...
\${result.note ? '⚠️ ' + result.note : ''}

🔍 TronScan: https://tronscan.org/#/transaction/\${result.txHash}\`;
        }`;

content = content.replace(oldSuccessMessage, newSuccessMessage);

fs.writeFileSync('src/bot/handlers/send.js', content);
console.log('✅ Send handler fee bilgisi eklendi!');
TEMPEOF

node temp_send_fix.js
rm temp_send_fix.js

echo "✅ Send handler güncellendi!"
