#!/bin/bash
# encoding: utf-8
# Скрипт создания backup базы данных перед применением индексов

set -e

echo "💾 Создание backup базы данных..."

# Создаем директорию backup если не существует
mkdir -p ../backup

# Генерируем имя файла с временной меткой
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="../backup/database_backup_stage1_${TIMESTAMP}.sql"
SCHEMA_FILE="../backup/schema_backup_stage1_${TIMESTAMP}.rb"

cd ../../../

# Получаем настройки базы данных
DB_CONFIG=$(bundle exec rails runner "puts Rails.application.config.database_configuration[Rails.env].to_json")
DB_NAME=$(echo $DB_CONFIG | ruby -rjson -e "puts JSON.parse(STDIN.read)['database']")
DB_HOST=$(echo $DB_CONFIG | ruby -rjson -e "puts JSON.parse(STDIN.read)['host'] || 'localhost'")
DB_USER=$(echo $DB_CONFIG | ruby -rjson -e "puts JSON.parse(STDIN.read)['username']")
DB_PASS=$(echo $DB_CONFIG | ruby -rjson -e "puts JSON.parse(STDIN.read)['password']")

echo "📄 Создание SQL backup базы: $DB_NAME"

# Создаем SQL backup
if [ -n "$DB_PASS" ]; then
    mysqldump -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "performance_optimizations/stage1_database_indexes/$BACKUP_FILE" 2>/dev/null
else
    mysqldump -h"$DB_HOST" -u"$DB_USER" "$DB_NAME" > "performance_optimizations/stage1_database_indexes/$BACKUP_FILE"
fi

if [ $? -eq 0 ]; then
    echo "✅ SQL backup создан: $BACKUP_FILE"
else
    echo "❌ Ошибка при создании SQL backup"
    exit 1
fi

# Создаем backup schema.rb
echo "📄 Создание backup schema.rb"
cp db/schema.rb "performance_optimizations/stage1_database_indexes/$SCHEMA_FILE"
echo "✅ Schema backup создан: $SCHEMA_FILE"

# Сохраняем информацию о backup в метаданные
BACKUP_INFO="performance_optimizations/stage1_database_indexes/backup/backup_info_${TIMESTAMP}.txt"

cat > "$BACKUP_INFO" << EOF
# Backup создан перед применением Stage 1: Database Indexes
# Дата: $(date)
# Команда: $0

Параметры базы данных:
- Имя: $DB_NAME
- Хост: $DB_HOST  
- Пользователь: $DB_USER

Файлы backup:
- SQL dump: $BACKUP_FILE
- Schema: $SCHEMA_FILE

Команда восстановления:
mysql -h"$DB_HOST" -u"$DB_USER" $([ -n "$DB_PASS" ] && echo "-p\"$DB_PASS\"") "$DB_NAME" < $BACKUP_FILE

Команда отката индексов:
./scripts/rollback_stage1.sh
EOF

echo "✅ Метаданные backup сохранены: $BACKUP_INFO"

# Проверяем размер созданного backup
BACKUP_SIZE=$(du -h "performance_optimizations/stage1_database_indexes/$BACKUP_FILE" | cut -f1)
echo "📊 Размер backup: $BACKUP_SIZE"

echo ""
echo "✅ Backup успешно создан!"
echo "💾 Местоположение: performance_optimizations/stage1_database_indexes/backup/"
echo "📋 Инструкции по восстановлению: $BACKUP_INFO"
echo ""
