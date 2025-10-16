# Рекомендации по оптимизации производительности базы данных

## 🚀 Критически важные индексы для добавления

### 1. Индексы для таблицы `smiles`
```sql
-- Для поиска отзывов по товарам через JSON
CREATE INDEX idx_smiles_json_order ON smiles(json_order);

-- Для сортировки по дате создания
CREATE INDEX idx_smiles_created_at ON smiles(created_at DESC);

-- Составной индекс для оптимизации пагинации
CREATE INDEX idx_smiles_created_product ON smiles(created_at DESC, json_order);

-- Для связи с заказами
CREATE INDEX idx_smiles_order_id ON smiles(order_eight_digit_id);
```

### 2. Индексы для таблицы `products`
```sql
-- Для поиска по названиям
CREATE INDEX idx_products_title ON products(title);
CREATE INDEX idx_products_header ON products(header);

-- Составной индекс для поиска и сортировки
CREATE INDEX idx_products_title_orderp ON products(title, orderp);

-- Для фильтрации по статусу и сортировки
CREATE INDEX idx_products_orderp ON products(orderp);
CREATE INDEX idx_products_default_price ON products(default_price);
```

### 3. Индексы для связующих таблиц
```sql
-- Для categories_products (уже может быть)
CREATE INDEX idx_categories_products_category ON categories_products(category_id);
CREATE INDEX idx_categories_products_product ON categories_products(product_id);
CREATE INDEX idx_categories_products_both ON categories_products(category_id, product_id);

-- Для product_complects
CREATE INDEX idx_product_complects_product ON product_complects(product_id);
CREATE INDEX idx_product_complects_complect ON product_complects(complect_id);
CREATE INDEX idx_product_complects_both ON product_complects(product_id, complect_id);

-- Для products_tags (если используется)
CREATE INDEX idx_products_tags_product ON products_tags(product_id);
CREATE INDEX idx_products_tags_tag ON products_tags(tag_id);
```

### 4. Индексы для таблицы `orders`
```sql
-- Для связи с отзывами и смайлами
CREATE INDEX idx_orders_eight_digit_id ON orders(eight_digit_id);

-- Для фильтрации по пользователям
CREATE INDEX idx_orders_useraccount_id ON orders(useraccount_id);

-- Для сортировки по дате
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

### 5. Индексы для таблицы `comments`
```sql
-- Для связи с заказами
CREATE INDEX idx_comments_order_eight_digit_id ON comments(order_eight_digit_id);

-- Для фильтрации по статусу публикации
CREATE INDEX idx_comments_published ON comments(published);

-- Для сортировки по дате
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);

-- Составной индекс для опубликованных комментариев
CREATE INDEX idx_comments_published_created ON comments(published, created_at DESC);
```

### 6. Индексы для таблицы `categories`
```sql
-- Для отображения на главной
CREATE INDEX idx_categories_show_in_index ON categories(show_in_index);

-- Для сортировки
CREATE INDEX idx_categories_sort_index ON categories(sort_index);

-- Для SEO урлов
CREATE INDEX idx_categories_slug ON categories(slug);
```

## 🔧 Оптимизация существующих запросов

### 1. Полнотекстовый поиск (для SQLite)
```sql
-- Включение FTS5 для поиска по продуктам
CREATE VIRTUAL TABLE products_fts USING fts5(title, header, description, content=products, content_rowid=id);

-- Триггеры для синхронизации
CREATE TRIGGER products_fts_insert AFTER INSERT ON products BEGIN
  INSERT INTO products_fts(rowid, title, header, description) VALUES (new.id, new.title, new.header, new.description);
END;

CREATE TRIGGER products_fts_update AFTER UPDATE ON products BEGIN
  UPDATE products_fts SET title=new.title, header=new.header, description=new.description WHERE rowid=new.id;
END;

CREATE TRIGGER products_fts_delete AFTER DELETE ON products BEGIN
  DELETE FROM products_fts WHERE rowid=old.id;
END;
```

### 2. Материализованные представления для часто используемых данных
```sql
-- Кэш продуктов с категориями (псевдо-материализованное представление через таблицу)
CREATE TABLE products_cache AS
SELECT 
  p.id,
  p.title,
  p.header,
  p.orderp,
  p.default_price,
  GROUP_CONCAT(c.id) as category_ids,
  GROUP_CONCAT(c.title, ', ') as category_titles
FROM products p
LEFT JOIN categories_products cp ON p.id = cp.product_id
LEFT JOIN categories c ON cp.category_id = c.id
GROUP BY p.id;

CREATE INDEX idx_products_cache_categories ON products_cache(category_ids);
CREATE INDEX idx_products_cache_orderp ON products_cache(orderp);
```

## 📊 Анализ производительности

### 1. Запросы для проверки использования индексов
```sql
-- SQLite: включение статистики запросов
PRAGMA stats = on;

-- Анализ плана выполнения критических запросов
EXPLAIN QUERY PLAN 
SELECT * FROM smiles WHERE json_order LIKE '%"id":"123"%' ORDER BY created_at DESC LIMIT 12;

EXPLAIN QUERY PLAN
SELECT p.* FROM products p 
JOIN categories_products cp ON p.id = cp.product_id 
JOIN product_complects pc ON p.id = pc.product_id 
ORDER BY p.orderp;
```

### 2. Мониторинг медленных запросов
```ruby
# В config/database.rb добавить логирование медленных запросов
if Rails.env.development?
  ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.logger.level = Logger::DEBUG
end

# Или в production для мониторинга
ActiveSupport::Notifications.subscribe('sql.active_record') do |name, started, finished, unique_id, data|
  duration = finished - started
  if duration > 0.1 # Логируем запросы дольше 100ms
    Rails.logger.warn "Slow query (#{duration.round(3)}s): #{data[:sql]}"
  uf
end
```

## 🎯 Приоритеты внедрения

### Высокий приоритет (критично для производительности):
1. Индекс для `smiles.json_order` - устранит самую большую проблему
2. Индексы для `products.title` и `products.header` - ускорит поиск в админке
3. Составные индексы для связующих таблиц

### Средний приоритет:
1. Индексы для сортировки (`created_at`, `orderp`)
2. Полнотекстовый поиск для продуктов

### Низкий приоритет:
1. Материализованные представления
2. Дополнительные аналитические индексы

## ⚠️ Важные замечания

1. **SQLite ограничения**: Некоторые индексы могут быть неэффективны в SQLite по сравнению с PostgreSQL/MySQL
2. **Размер базы**: Индексы увеличивают размер базы данных на ~20-30%
3. **Вставка данных**: Множественные индексы замедляют операции INSERT/UPDATE
4. **Тестирование**: Обязательно протестируйте каждый индекс на реальных данных

## 🔍 Команды для создания индексов

Создайте миграцию или выполните SQL команды напрямую:

```bash
# Создание миграции
rails generate migration AddPerformanceIndexes

# Или выполнение через sqlite3
sqlite3 db/rozario_production.db < performance_indexes.sql
```

После добавления индексов производительность критических операций должна улучшиться в 5-10 раз.
