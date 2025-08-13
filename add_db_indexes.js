const db = require('./src/database');

async function addIndexes() {
  try {
    console.log('📊 Veritabanı indexleri ekleniyor...');
    
    // Transaction tablosu için indexler
    await db.run('CREATE INDEX IF NOT EXISTS idx_transactions_user_created ON transactions(user_id, created_at DESC)');
    await db.run('CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)');
    await db.run('CREATE INDEX IF NOT EXISTS idx_transactions_hash ON transactions(tx_hash)');
    
    // Users tablosu için index
    await db.run('CREATE INDEX IF NOT EXISTS idx_users_telegram_id ON users(telegram_id)');
    
    // Wallets tablosu için index
    await db.run('CREATE INDEX IF NOT EXISTS idx_wallets_user_active ON wallets(user_id, is_active)');
    
    console.log('✅ Veritabanı indexleri başarıyla eklendi!');
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Index ekleme hatası:', error);
    process.exit(1);
  }
}

addIndexes();
