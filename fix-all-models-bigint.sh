#!/bin/bash
echo "🔧 Tüm modellerde BIGINT düzeltmesi..."

# User modeli - telegram_id BIGINT
cat > src/database/models/User.js << 'USEREOF'
const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const User = sequelize.define('User', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    telegram_id: {
      type: DataTypes.BIGINT,
      allowNull: false,
      unique: true
    },
    username: {
      type: DataTypes.STRING(32),
      allowNull: true
    },
    first_name: {
      type: DataTypes.STRING(64),
      allowNull: true
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    security_level: {
      type: DataTypes.ENUM('basic', 'medium', 'high'),
      defaultValue: 'basic'
    },
    daily_limit: {
      type: DataTypes.DECIMAL(18, 6),
      defaultValue: 1000.00
    },
    master_password_hash: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    last_activity: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW
    }
  }, {
    tableName: 'users',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at'
  });

  return User;
};
USEREOF

# Wallet modeli - user_id normal INTEGER (FK)
cat > src/database/models/Wallet.js << 'WALLETEOF'
const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Wallet = sequelize.define('Wallet', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    name: {
      type: DataTypes.STRING(50),
      allowNull: false
    },
    address: {
      type: DataTypes.STRING(42),
      allowNull: false
    },
    encrypted_private_key: {
      type: DataTypes.TEXT,
      allowNull: false
    },
    salt: {
      type: DataTypes.STRING(128),
      allowNull: false
    },
    iv: {
      type: DataTypes.STRING(32),
      allowNull: false
    },
    tag: {
      type: DataTypes.STRING(32),
      allowNull: false
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    }
  }, {
    tableName: 'wallets',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at'
  });

  return Wallet;
};
WALLETEOF

# Transaction modeli - user_id normal INTEGER (FK)
cat > src/database/models/Transaction.js << 'TXEOF'
const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const Transaction = sequelize.define('Transaction', {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    user_id: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'users',
        key: 'id'
      }
    },
    from_wallet: {
      type: DataTypes.STRING(42),
      allowNull: false
    },
    to_address: {
      type: DataTypes.STRING(42),
      allowNull: false
    },
    amount: {
      type: DataTypes.DECIMAL(18, 6),
      allowNull: false
    },
    tx_hash: {
      type: DataTypes.STRING(64),
      allowNull: true
    },
    status: {
      type: DataTypes.ENUM('pending', 'confirmed', 'failed'),
      defaultValue: 'pending'
    }
  }, {
    tableName: 'transactions',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at'
  });

  return Transaction;
};
TXEOF

echo "✅ Tüm modeller düzeltildi!"
