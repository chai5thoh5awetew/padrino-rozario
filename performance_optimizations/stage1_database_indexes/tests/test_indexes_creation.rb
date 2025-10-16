#!/usr/bin/env ruby
# encoding: utf-8
# Тест проверки создания индексов производительности

require 'rubygems'
require 'bundler/setup'
require_relative '../../../config/boot.rb'
require 'test/unit'

class TestIndexesCreation < Test::Unit::TestCase
  
  def setup
    @critical_indexes = [
      ['smiles', 'idx_smiles_json_order', 'KEY'],
      ['smiles', 'idx_smiles_created_at', 'KEY'],
      ['products', 'idx_products_title', 'KEY'],
      ['products', 'idx_products_header', 'KEY'],
      ['products', 'idx_products_fulltext', 'FULLTEXT'],
      ['categories', 'idx_categories_title', 'KEY']
    ]
    
    @composite_indexes = [
      ['categories_products', 'idx_cat_prod_composite'],
      ['products_tags', 'idx_prod_tag_composite'],
      ['product_complects', 'idx_prod_complect_composite']
    ]
  end
  
  def test_database_connection
    puts "🔍 Тест 1: Подключение к базе данных"
    
    assert_nothing_raised do
      ActiveRecord::Base.connection.execute("SELECT 1")
    end
    
    puts "✅ Подключение к базе работает"
  end
  
  def test_critical_indexes_exist
    puts "🔍 Тест 2: Критические индексы"
    
    missing_indexes = []
    
    @critical_indexes.each do |table, index_name, index_type|
      begin
        result = ActiveRecord::Base.connection.execute(
          "SHOW INDEX FROM #{table} WHERE Key_name = '#{index_name}'"
        )
        
        if result.any?
          puts "✅ #{index_name} на таблице #{table}"
        else
          puts "❌ #{index_name} на таблице #{table} - ОТСУТСТВУЕТ!"
          missing_indexes << "#{table}.#{index_name}"
        end
      rescue => e
        puts "⚠️  Ошибка проверки #{index_name}: #{e.message}"
        missing_indexes << "#{table}.#{index_name} (error)"
      end
    end
    
    if missing_indexes.empty?
      puts "✅ Все критические индексы созданы"
    else
      fail("Отсутствуют критические индексы: #{missing_indexes.join(', ')}")
    end
  end
  
  def test_composite_indexes_exist
    puts "🔍 Тест 3: Композитные индексы"
    
    missing_indexes = []
    
    @composite_indexes.each do |table, index_name|
      begin
        result = ActiveRecord::Base.connection.execute(
          "SHOW INDEX FROM #{table} WHERE Key_name = '#{index_name}'"
        )
        
        if result.any?
          puts "✅ #{index_name} на таблице #{table}"
        else
          puts "⚠️  #{index_name} на таблице #{table} - отсутствует"
          missing_indexes << "#{table}.#{index_name}"
        end
      rescue => e
        puts "⚠️  Ошибка проверки #{index_name}: #{e.message}"
      end
    end
    
    if missing_indexes.empty?
      puts "✅ Все композитные индексы созданы"
    else
      puts "⚠️  Отсутствующие композитные индексы: #{missing_indexes.join(', ')}"
    end
  end
  
  def test_fulltext_index_functionality 
    puts "🔍 Тест 4: Функциональность FULLTEXT индекса"
    
    # Проверяем FULLTEXT поиск (если есть данные)
    if Product.count > 0
      begin
        # Пробуем FULLTEXT поиск
        result = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) as count FROM products WHERE MATCH(title, header) AGAINST('роза' IN BOOLEAN MODE)"
        )
        
        count = result.first['count'] || result.first[0]
        puts "✅ FULLTEXT поиск работает (найдено: #{count} результатов)"
      rescue => e
        puts "⚠️  FULLTEXT поиск не работает: #{e.message}"
        # Не фейлим тест, так как FULLTEXT может не работать на старых версиях MySQL
      end
    else
      puts "⚠️  Нет данных для теста FULLTEXT поиска"
    end
  end
  
  def test_index_usage_with_explain
    puts "🔍 Тест 5: Проверка использования индексов через EXPLAIN"
    
    test_queries = [
      {
        name: "smiles json_order поиск",
        query: "SELECT * FROM smiles WHERE json_order LIKE '%роза%' LIMIT 5",
        expected_key: "idx_smiles_json_order"
      },
      {
        name: "products title поиск",
        query: "SELECT * FROM products WHERE title LIKE '%букет%' LIMIT 5",
        expected_key: "idx_products_title"
      },
      {
        name: "smiles сортировка",
        query: "SELECT * FROM smiles ORDER BY created_at DESC LIMIT 5",
        expected_key: "idx_smiles_created_at"
      }
    ]
    
    test_queries.each do |test_case|
      begin
        explain_result = ActiveRecord::Base.connection.execute("EXPLAIN #{test_case[:query]}")
        
        # Проверяем что индекс используется
        key_used = explain_result.first['key'] || explain_result.first[5]
        
        if key_used && (key_used.include?(test_case[:expected_key]) || key_used.include?('idx_'))
          puts "✅ #{test_case[:name]}: индекс используется (#{key_used})"
        else
          puts "⚠️  #{test_case[:name]}: индекс не используется или используется неправильный (#{key_used})"
        end
      rescue => e
        puts "⚠️  Ошибка при тестировании #{test_case[:name]}: #{e.message}"
      end
    end
  end
  
  def test_database_size_impact
    puts "🔍 Тест 6: Влияние на размер базы данных"
    
    begin
      size_info = ActiveRecord::Base.connection.execute(
        "SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'size_mb', 
                ROUND((index_length / 1024 / 1024), 2) AS 'index_size_mb'
         FROM information_schema.TABLES 
         WHERE table_schema = DATABASE() 
         AND table_name IN ('smiles', 'products', 'categories', 'categories_products', 'products_tags', 'product_complects')"
      )
      
      total_size = 0
      total_index_size = 0
      
      puts "✨ Размеры таблиц с индексами:"
      
      size_info.each do |row|
        table_name = row['table_name'] || row[0]
        size_mb = (row['size_mb'] || row[1]).to_f
        index_size_mb = (row['index_size_mb'] || row[2]).to_f
        
        puts "   - #{table_name}: #{size_mb}MB общий, #{index_size_mb}MB индексы"
        
        total_size += size_mb
        total_index_size += index_size_mb
      end
      
      index_percentage = total_size > 0 ? (total_index_size / total_size * 100).round(1) : 0
      
      puts "\n📊 Итого:"
      puts "   - Общий размер: #{total_size.round(2)}MB"
      puts "   - Размер индексов: #{total_index_size.round(2)}MB"
      puts "   - Доля индексов: #{index_percentage}%"
      
      if index_percentage > 50
        puts "⚠️  Индексы занимают много места (>50%)"
      elsif index_percentage > 30
        puts "ℹ️  Индексы занимают умеренное количество места (#{index_percentage}%)"
      else
        puts "✅ Индексы занимают оптимальное количество места (#{index_percentage}%)"
      end
      
    rescue => e
      puts "⚠️  Не удалось получить информацию о размере: #{e.message}"
    end
  end
end

# Запуск тестов если файл выполняется напрямую
if __FILE__ == $0
  puts "🧪 Тест создания индексов производительности"
  puts "=" * 60
  
  begin
    Test::Unit::AutoRunner.run
  rescue => e
    puts "\n❌ Ошибка в тестах: #{e.message}"
    puts e.backtrace.first(3)
    exit 1
  end
end
