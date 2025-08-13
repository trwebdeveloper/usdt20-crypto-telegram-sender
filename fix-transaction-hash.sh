#!/bin/bash
echo "🔧 Transaction hash düzeltiliyor..."

# Tron.js sendUsdt fonksiyonunu güncelle
sed -i 's/logger.info(`✅ USDT transfer tamamlandı: ${transaction}`);/logger.info(`✅ USDT transfer tamamlandı:`, transaction);/' src/blockchain/tron.js

# Transaction return düzeltmesi
cat > temp_tron_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/blockchain/tron.js', 'utf8');

// sendUsdt fonksiyonundaki return kısmını düzelt
content = content.replace(
  /return {\s*txHash: transaction,/,
  `return {
        txHash: typeof transaction === 'string' ? transaction : (transaction.txid || transaction.transaction?.txID || 'pending'),`
);

fs.writeFileSync('src/blockchain/tron.js', content);
console.log('✅ Transaction hash formatı düzeltildi!');
TEMPEOF

node temp_tron_fix.js
rm temp_tron_fix.js

echo "✅ Transaction hash düzeltmesi tamamlandı!"
