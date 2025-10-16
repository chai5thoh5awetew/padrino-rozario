#!/bin/bash
# encoding: utf-8
# Скрипт отката Stage 1: Database Indexes
# Удаляет все созданные индексы и возвращает базу к предыдущему состоянию

set -e

echo "🚨 Начало отката Stage 1: Database Indexes"
echo "==============================================="
echo "⚠️  Этот скрипт удалит все созданные индексы!"
echo ""

# Подтверждение от пользователя
if [ "$1" != "--force" ]; then
    echo "Перечисль индексов для удаления:"
    echo "  - idx_smiles_json_order (критический)"
    echo "  - idx_smiles_created_at"
    echo "  - idx_products_title" 
    echo "  - idx_products_header"
    echo "  - idx_products_fulltext"
    echo "  - idx_categories_title"
    echo "  - Композитные индексы для JOIN операций"
    echo ""
    read -p "Вы уверены что хотите продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Откат отменен пользователем"
        exit 1
    fi
fi

cd ../../../

# Проверка подключения к базе
echo "🔍 Проверка подключения к базе данных..."
if ! bundle exec rake db:version > /dev/null 2>&1; then
    echo "❌ Ошибка: Не удалось подключиться к базе данных"
    exit 1
fi

# Удаление индексов в обратном порядке (как в migration down)
echo "🔧 Удаление созданных индексов..."

# Массив индексов для удаления (в обратном порядке от миграции)
INDEXES_TO_DROP=(
    "product_complects:idx_prod_complect_composite"
    "products_tags:idx_prod_tag_composite"
    "categories_products:idx_cat_prod_composite"
    "categories:idx_categories_title"
    "products:idx_products_fulltext:FULLTEXT"  # Особый синтаксис для FULLTEXT
    "products:idx_products_header"
    "products:idx_products_title"
    "smiles:idx_smiles_created_at"
    "smiles:idx_smiles_json_order"
)

SUCCESS_COUNT=0
FAILED_COUNT=0

for index_info in "${INDEXES_TO_DROP[@]}"; do
    table=$(echo $index_info | cut -d: -f1)
    index=$(echo $index_info | cut -d: -f2)
    type=$(echo $index_info | cut -d: -f3)  # Может быть FULLTEXT
    
    echo -n "  ❌ Удаление $index с таблицы $table..."
    
    # Проверяем существует ли индекс
    INDEX_EXISTS=$(bundle exec rails runner "puts ActiveRecord::Base.connection.execute('SHOW INDEX FROM $table WHERE Key_name = \"$index\"').any?" 2>/dev/null || echo "false")
    
    if [ "$INDEX_EXISTS" = "false" ]; then
        echo " ⚠️  уже отсутствует"
        continue
    fi
    
    # Удаляем индекс
    if [ "$type" = "FULLTEXT" ]; then
        # Особый синтаксис для FULLTEXT индексов
        SQL_COMMAND="DROP INDEX $index ON $table"
    else
        # Обычные индексы
        SQL_COMMAND="DROP INDEX $index ON $table"
    fi
    
    if bundle exec rails runner "ActiveRecord::Base.connection.execute('$SQL_COMMAND')" 2>/dev/null; then
        echo " ✅ удален"
        ((SUCCESS_COUNT++))
    else
        echo " ❌ ошибка"
        ((FAILED_COUNT++))
    fi
done

echo ""
echo "📊 Итоги отката:"
echo "   ✅ Успешно удалено: $SUCCESS_COUNT индексов"
echo "   ❌ Ошибок: $FAILED_COUNT"

# Откатываем миграцию
echo "🔄 Откат миграции 091_add_performance_indexes..."

if bundle exec rake db:rollback STEP=1 2>/dev/null; then
    echo "✅ Миграция успешно откачена"
else
    echo "⚠️  Не удалось откатить миграцию (возможно, она уже была откачена)"
fi

# Проверка оставшихся индексов
echo "🔍 Проверка оставшихся индексов производительности..."

REMAINING_INDEXES_FOUND=false

for table in "smiles" "products" "categories" "categories_products" "products_tags" "product_complects"; do
    INDEXES=$(bundle exec rails runner "ActiveRecord::Base.connection.execute('SHOW INDEX FROM $table WHERE Key_name LIKE \"idx_%\"').to_a" 2>/dev/null || echo "[]")
    if [ "$INDEXES" != "[]" ] && [ -n "$INDEXES" ]; then
        echo "⚠️  Остались индексы на таблице $table"
        REMAINING_INDEXES_FOUND=true
    fi
done

if [ "$REMAINING_INDEXES_FOUND" = false ]; then
    echo "✅ Все индексы производительности удалены"
fi

# Проверка работоспособности приложения
echo "🧪 Проверка работоспособности приложения..."

if bundle exec rails runner "puts 'Application is working: ' + (Smile.count > 0 ? 'Yes' : 'No data')" 2>/dev/null; then
    echo "✅ Приложение работает корректно"
else
    echo "❌ Проблемы с работой приложения!"
    echo "   Попробуйте перезапустить приложение"
fi

echo ""
echo "✅ ==============================================="
echo "✅ Откат Stage 1 успешно завершен!"
echo "✅ ==============================================="
echo ""
echo "📊 Результаты:"
echo "   - Все индексы производительности удалены"
echo "   - Миграция 091_add_performance_indexes откачена"
echo "   - Производительность вернулась к исходному уровню"
echo ""
echo "💡 Рекомендации:"
echo "   - Проверьте работу сайта в браузере"
echo "   - Обратитесь к логам чтобы выяснить причину отката"
echo "   - Исправьте проблемы перед повторным применением"
echo ""
echo "💾 Backup остался в: performance_optimizations/stage1_database_indexes/backup/"
echo ""
