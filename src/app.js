require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const logger = require('./utils/logger');
const db = require('./database');
const CryptoBot = require('./bot');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Ana uygulama başlatma
async function startApp() {
  try {
    // Veritabanını test et
    logger.info('📊 Veritabanı bağlantısı test ediliyor...');
    await db.run('SELECT 1');
    logger.info('✅ Veritabanı bağlantısı başarılı!');

    // Express sunucusu başlat
    app.listen(PORT, () => {
      logger.info(`🚀 Express sunucu ${PORT} portunda çalışıyor`);
    });

    // Telegram Bot başlat
    logger.info('🤖 Telegram bot başlatılıyor...');
    const bot = new CryptoBot(process.env.BOT_TOKEN);
    bot.start();

  } catch (error) {
    logger.error('💥 BAŞLATMA HATASI:');
    logger.error('==================');
    logger.error(`Hata: ${error.message}`);
    logger.error('==================');
    process.exit(1);
  }
}

// Uygulamayı başlat
startApp();

// Graceful shutdown
process.on('SIGINT', () => {
  logger.info('👋 Uygulama kapatılıyor...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('👋 Uygulama kapatılıyor...');
  process.exit(0);
});
