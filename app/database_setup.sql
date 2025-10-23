CREATE DATABASE IF NOT EXISTS automation_ui;
USE automation_ui;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(100),
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL,
    INDEX (username)
);

-- admin/admin123 and user/password
INSERT INTO users (username, password_hash, email, full_name) VALUES
('admin', '$2b$12$G7eB4Hf6bt/Jv0FyPNqDIOC/uMJ/JxCyogGXZgiaG3o6UAAzBBeQ.', 'admin@example.com', 'Administrator'),
('user', '$2b$12$LWfd.SaZG.n9aHpgJ8sxKeAT1oXGToLGP2IzJ91Y.er8CjIDKSi9i', 'user@example.com', 'Standard User');

CREATE TABLE IF NOT EXISTS automation_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    automation_id VARCHAR(50) NOT NULL,
    automation_name VARCHAR(100),
    parameters TEXT,
    success BOOLEAN,
    output TEXT,
    execution_time FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX (user_id),
    INDEX (automation_id),
    INDEX (created_at)
);

SELECT username, email, full_name FROM users;
