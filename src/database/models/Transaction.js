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
