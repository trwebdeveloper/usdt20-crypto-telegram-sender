#!/bin/bash
echo "🔧 Syntax hatası düzeltiliyor..."

# Send handler'daki syntax hatasını düzelt
sed -i "s/const loadingMsg = await ctx.reply('🔄 İşlem blockchain'e gönderiliyor...\\\\n\\\\n⏳ Lütfen bekleyin, confirmation bekleniyor (max 2 dakika)');/const loadingMsg = await ctx.reply('🔄 İşlem blockchain gönderiliyor...\\\\n\\\\n⏳ Lütfen bekleyin, confirmation bekleniyor (max 2 dakika)');/" src/bot/handlers/send.js

# Alternatif - backtick kullan
cat > temp_syntax_fix.js << 'TEMPEOF'
const fs = require('fs');
let content = fs.readFileSync('src/bot/handlers/send.js', 'utf8');

// Problematik satırı bul ve düzelt
content = content.replace(
  /const loadingMsg = await ctx\.reply\('🔄 İşlem blockchain'e.*?\);/,
  "const loadingMsg = await ctx.reply(`🔄 İşlem blockchain'e gönderiliyor...\\n\\n⏳ Lütfen bekleyin, confirmation bekleniyor (max 2 dakika)`);"
);

fs.writeFileSync('src/bot/handlers/send.js', content);
console.log('✅ Syntax hatası düzeltildi!');
TEMPEOF

node temp_syntax_fix.js
rm temp_syntax_fix.js

echo "✅ Send handler syntax hatası düzeltildi!"
