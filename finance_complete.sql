-- Single shared DB
CREATE DATABASE IF NOT EXISTS finance_app
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE finance_app;

-- Optional users table (future multi-user and premium flags)
CREATE TABLE IF NOT EXISTS users (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  email         VARCHAR(191) UNIQUE,
  display_name  VARCHAR(191),
  is_premium    TINYINT(1) NOT NULL DEFAULT 0,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Categories (user-addable)
CREATE TABLE IF NOT EXISTS categories (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NULL,
  name          VARCHAR(100) NOT NULL,
  color_hex     CHAR(7) NULL,               -- e.g. #FF5722
  icon_name     VARCHAR(64) NULL,           -- app icon mapping, optional
  is_system     TINYINT(1) NOT NULL DEFAULT 0,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_category_user_name (user_id, name),
  CONSTRAINT fk_category_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Labels/Tags (supports multiple per expense)
CREATE TABLE IF NOT EXISTS labels (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NULL,
  name          VARCHAR(100) NOT NULL,
  color_hex     CHAR(7) NULL,
  is_system     TINYINT(1) NOT NULL DEFAULT 0,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_label_user_name (user_id, name),
  CONSTRAINT fk_label_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Payment Methods
CREATE TABLE IF NOT EXISTS payment_methods (
  id            BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id       BIGINT UNSIGNED NULL,
  name          VARCHAR(120) NOT NULL,  -- e.g., “HDFC Credit Card”, “Cash”
  type          VARCHAR(40) NOT NULL,   -- cash, card, upi, bank_transfer, wallet, other
  details_json  JSON NULL,              -- masked last4, issuer, etc.
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_payment_method_user_name (user_id, name),
  CONSTRAINT fk_payment_method_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Expenses
CREATE TABLE IF NOT EXISTS expenses (
  id                 BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id            BIGINT UNSIGNED NULL,
  amount             DECIMAL(12,2) NOT NULL,
  currency           CHAR(3) NOT NULL DEFAULT 'INR',
  txn_date           DATE NOT NULL,
  payee              VARCHAR(191) NOT NULL,      -- Payee / Item
  description        VARCHAR(300) NULL,          -- optional details
  category_id        BIGINT UNSIGNED NULL,
  payment_method_id  BIGINT UNSIGNED NULL,
  notes              TEXT NULL,
  is_recurring       TINYINT(1) NOT NULL DEFAULT 0,
  created_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  deleted_at         TIMESTAMP NULL DEFAULT NULL, -- soft delete
  INDEX idx_expenses_user_date (user_id, txn_date),
  INDEX idx_expenses_category (category_id),
  INDEX idx_expenses_payment_method (payment_method_id),
  INDEX idx_expenses_amount (amount),
  CONSTRAINT fk_expense_user
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_expense_category
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
  CONSTRAINT fk_expense_payment_method
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Many-to-many: expense ↔ labels
CREATE TABLE IF NOT EXISTS expense_labels (
  expense_id BIGINT UNSIGNED NOT NULL,
  label_id   BIGINT UNSIGNED NOT NULL,
  is_primary TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (expense_id, label_id),
  CONSTRAINT fk_expense_labels_expense
    FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE,
  CONSTRAINT fk_expense_labels_label
    FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Optional attachments (receipts, images)
CREATE TABLE IF NOT EXISTS expense_attachments (
  id          BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  expense_id  BIGINT UNSIGNED NOT NULL,
  file_url    VARCHAR(500) NOT NULL,
  mime_type   VARCHAR(100) NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_expense_attachment_expense
    FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
) ENGINE=InnoDB;