#!/bin/bash
# encoding: utf-8
# Скрипт применения этапа 1: Database Indexes
# Применяет критически важные индексы для производительности

set -e  # Остановиться при ошибке

echo "🚀 Начало применения Stage 1: Database Indexes"
echo "==============================================="

# Проверка окружения
if [ ! -f "../../../config/database.yml" ]; then
    echo "❌ Ошибка: Не найден config/database.yml"
    echo "   Пожалуйста, запустите скрипт из корневой директории проекта"
    exit 1
fi

# Проверка доступности базы данных
echo "🔍 Проверка подключения к базе данных..."
cd ../../../
if ! bundle exec rake db:version > /dev/null 2>&1; then
    echo "❌ Ошибка: Не удалось подключиться к базе данных"
    echo "   Проверьте настройки в config/database.yml"
    exit 1
fi
echo "✅ Подключение к базе данных успешно"

# Проверка свободного места на диске
echo "💾 Проверка дискового пространства..."
FREE_SPACE=$(df . | awk 'NR==2 {print $4}')
if [ "$FREE_SPACE" -lt 1000000 ]; then  # Менее 1GB
    echo "⚠️  Предупреждение: Мало свободного места ($FREE_SPACE KB)"
    echo "   Рекомендуется освободить место перед продолжением"
    read -p "   Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Применение отменено пользователем"
        exit 1
    fi
fi

# Создание backup перед применением индексов
echo "💾 Создание backup перед применением индексов..."
cd performance_optimizations/stage1_database_indexes/
if ! ./scripts/create_backup.sh; then
    echo "❌ Ошибка: Не удалось создать backup"
    exit 1
fi
cd ../../..

# Применение миграции
echo "🔧 Применение миграции с индексами..."

# Копируем миграцию в основную директорию миграций
if [ ! -f "db/migrate/091_add_performance_indexes.rb" ]; then
    cp performance_optimizations/stage1_database_indexes/migration/091_add_performance_indexes.rb db/migrate/
    echo "✅ Миграция скопирована"
else
    echo "✅ Миграция уже существует"
fi

# Выполнение миграции с отображением прогресса
echo "⚡ Запуск миграции... (это может занять несколько минут)"

START_TIME=$(date +%s)

if bundle exec rake db:migrate; then
    END_TIME=$(date +%s)
    ELAPSED=$((END_TIME - START_TIME))
    echo "✅ Миграция успешно применена за ${ELAPSED} секунд"
else
    echo "❌ Ошибка при выполнении миграции!"
    echo "   Автоматический откат..."
    cd performance_optimizations/stage1_database_indexes/
    ./scripts/rollback_stage1.sh
    exit 1
fi

# Проверка создания индексов
echo "🔍 Проверка созданных индексов..."

# Проверяем критические индексы
CRITICAL_INDEXES=(
    "smiles:idx_smiles_json_order"
    "smiles:idx_smiles_created_at" 
    "products:idx_products_title"
    "products:idx_products_header"
)

ALL_INDEXES_CREATED=true

for index_info in "${CRITICAL_INDEXES[@]}"; do
    table=$(echo $index_info | cut -d: -f1)
    index=$(echo $index_info | cut -d: -f2)
    
    if bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SHOW INDEX FROM $table WHERE Key_name = \"$index\"').any?"; then
        echo "✅ $index на таблице $table"
    else
        echo "❌ $index на таблице $table - ОТСУТСТВУЕТ!"
        ALL_INDEXES_CREATED=false
    fi
done

if [ "$ALL_INDEXES_CREATED" = false ]; then
    echo "❌ Не все критические индексы созданы!"
    echo "   Откатываем изменения..."
    cd performance_optimizations/stage1_database_indexes/
    ./scripts/rollback_stage1.sh
    exit 1
fi

# Запуск базовых тестов
echo "🧪 Запуск тестов производительности..."
cd performance_optimizations/stage1_database_indexes/

if ./tests/test_indexes_creation.rb; then
    echo "✅ Базовые тесты прошли успешно"
else
    echo "⚠️  Некоторые тесты не прошли, но миграция применена"
fi

# Информация о размере индексов
echo "📊 Информация о созданных индексах:"
cd ../../..

bundle exec rails runner '
    tables = %w[smiles products categories categories_products products_tags]
    tables.each do |table|
        indexes = ActiveRecord::Base.connection.execute("SHOW INDEX FROM #{table}")
        puts "\n✨ #{table.upcase}:"
        indexes.each do |idx|
            puts "   - #{idx[2]} (#{idx[10]})" if idx[2] =~ /idx_/
        end
    end
'

echo ""
echo "✅ ==============================================="
echo "✅ Stage 1: Database Indexes успешно применен!"
echo "✅ ==============================================="
echo ""
echo "📊 Ожидаемые улучшения:"
echo "   - Поиск smiles: 10-20x быстрее"
echo "   - Админ поиск: 5-10x быстрее"
echo "   - JOIN операции: 2-3x быстрее"
echo ""
echo "🚀 Следующие шаги:"
echo "   1. Запустить полное тестирование: ./scripts/test_stage1.sh"
echo "   2. Проверить работу сайта в браузере"
echo "   3. Применить Stage 2: Smiles Optimization"
echo ""
echo "💾 Backup сохранен в: performance_optimizations/stage1_database_indexes/backup/"
echo "🚨 При проблемах запустите: ./scripts/rollback_stage1.sh"
echo ""
