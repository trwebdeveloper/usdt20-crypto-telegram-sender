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
