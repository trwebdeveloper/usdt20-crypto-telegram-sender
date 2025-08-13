#!/bin/bash
echo "🔧 Confirmation callback logic düzeltiliyor..."

cat > temp_callback_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/bot/handlers/send.js', 'utf8');

// Confirmation callback'indeki if-else logic'i tamamen değiştir
const oldCallbackLogic = /if \(confirmationData\.success\) \{[\s\S]*?\} else \{[\s\S]*?\}/;

const newCallbackLogic = `if (confirmationData.success === true) {
          // ✅ Başarılı işlem - DETAYLI MESAJ
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

🎉 **USDT başarıyla gönderildi!**\`;

        } else if (confirmationData.success === false) {
          // ❌ Başarısız işlem
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

💡 **Not:** İşlem başarısız oldu, USDT gönderilmedi.\`;

        } else if (confirmationData.timeout) {
          // ⏰ Timeout - hiç mesaj gönderme, return et
          logger.info(\`Timeout için mesaj gönderilmedi: \${confirmationData.txHash}\`);
          return;
          
        } else if (confirmationData.error) {
          // 🔍 Error - hiç mesaj gönderme, return et  
          logger.info(\`Error için mesaj gönderilmedi: \${confirmationData.txHash}\`);
          return;
          
        } else {
          // 🚫 Belirsiz durum - hiç mesaj gönderme, return et
          logger.warn(\`Belirsiz confirmation data:\`, confirmationData);
          return;
        }`;

content = content.replace(oldCallbackLogic, newCallbackLogic);

fs.writeFileSync('src/bot/handlers/send.js', content);
console.log('✅ Confirmation callback logic düzeltildi!');
TEMPEOF

node temp_callback_fix.js
rm temp_callback_fix.js

echo "✅ Confirmation callback düzeltildi!"
