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
