#!/usr/bin/env ruby
# encoding: utf-8
# СКРИПТ ДЛЯ ТЕСТИРОВАНИЯ ПРОИЗВОДИТЕЛЬНОСТИ ОПТИМИЗАЦИЙ
# Проверяет критические операции по скорости выполнения

require 'rubygems'
require 'bundler/setup'
require './config/boot.rb'
require 'benchmark'

class PerformanceTest
  def initialize
    puts "📊 ТЕСТИРОВАНИЕ ПРОИЗВОДИТЕЛЬНОСТИ ОПТИМИЗАЦИЙ Розарио.Цветы"
    puts "="*80
  end
  
  def test_smiles_search
    puts "🔍 Тест 1: Поиск smiles (основная проблема)"
    
    unless Smile.count > 0
      puts "⚠️  Нет smiles в базе для теста"
      return
    end
    
    search_term = "роз"
    
    # Старый метод - Smile.all (catastrophic)
    puts "🔴 Старый метод (Smile.all):"
    old_time = Benchmark.measure do
      @old_results = Smile.all.select do |smile|
        next false if smile.json_order.blank?
        
        begin
          json_data = JSON.parse(smile.json_order)
          json_data['title']&.include?(search_term) || 
          json_data['name']&.include?(search_term)
        rescue JSON::ParserError
          false
        end
      end
    end
    
    puts "   ⏱️  Время: #{old_time.real.round(3)} сек"
    puts "   📊 Найдено: #{@old_results.size} smiles"
    puts "   💾 Запросов: #{Smile.count} (все smiles загружены в память)"
    
    # Новый оптимизированный метод
    puts "🔍 Новый оптимизированный метод (SQL LIKE):"
    new_time = Benchmark.measure do
      @new_results = Smile.where("json_order LIKE ?", "%#{search_term}%")
                         .limit(100)
                         .to_a
    end
    
    puts "   ⏱️  Время: #{new_time.real.round(3)} сек"
    puts "   📊 Найдено: #{@new_results.size} smiles"
    puts "   💾 Запросов: 1 (только SQL LIKE)"
    
    # Сравнение результатов
    speedup = old_time.real / new_time.real
    puts "⚡ УЛУЧШЕНИЕ: #{speedup.round(1)}x быстрее!"
    puts
  end
  
  def test_product_search
    puts "🔍 Тест 2: Поиск продуктов (админ панель)"
    
    unless Product.count > 0
      puts "⚠️  Нет продуктов в базе для теста"
      return
    end
    
    search_term = "роз"
    
    # Старый метод - Product.all (catastrophic)
    puts "🔴 Старый метод (Product.all):"
    old_time = Benchmark.measure do
      @old_products = Product.all.select do |product|
        product.title&.include?(search_term) || 
        product.header&.include?(search_term) ||
        product.keywords&.include?(search_term)
      end
    end
    
    puts "   ⏱️  Время: #{old_time.real.round(3)} сек"
    puts "   📊 Найдено: #{@old_products.size} продуктов"
    puts "   💾 Запросов: #{Product.count} (все продукты загружены)"
    
    # Новый оптимизированный метод
    puts "🔍 Новый оптимизированный метод (search_optimized):"
    new_time = Benchmark.measure do
      @new_products = Product.search_optimized(search_term, 50)
    end
    
    puts "   ⏱️  Время: #{new_time.real.round(3)} сек"
    puts "   📊 Найдено: #{@new_products.size} продуктов"
    puts "   💾 Запросов: 1 (только SQL с индексами)"
    
    # Сравнение результатов
    if old_time.real > 0 && new_time.real > 0
      speedup = old_time.real / new_time.real
      puts "⚡ УЛУЧШЕНИЕ: #{speedup.round(1)}x быстрее!"
    end
    puts
  end
  
  def test_catalog_performance
    puts "📋 Тест 3: Каталог продуктов (get_catalog)"
    
    # Получаем первые субдомен и категорию
    subdomain = Subdomain.first
    subdomain_pool = SubdomainPool.first 
    category = Category.first
    
    unless subdomain && subdomain_pool && category
      puts "⚠️  Нет необходимых данных для теста каталога"
      return 
    end
    
    puts "🔍 Оптимизированный каталог (get_catalog_optimized):"
    
    catalog_time = Benchmark.measure do
      @catalog_results = Product.get_catalog_optimized(
        subdomain, 
        subdomain_pool, 
        [category],
        nil, # tags
        0,   # min_price
        100000, # max_price
        'price_asc', # sort_by
        20,  # limit
        0    # offset
      )
    end
    
    puts "   ⏱️  Время: #{catalog_time.real.round(3)} сек"
    puts "   📊 Найдено: #{@catalog_results.size} продуктов"
    puts "   📋 Положен в кэш на 10 минут"
    
    # Повторный вызов (должен быть быстрым из-за кэша)
    puts "💾 Повторный вызов (из кэша):"
    
    cached_time = Benchmark.measure do
      @cached_results = Product.get_catalog_optimized(
        subdomain,
        subdomain_pool,
        [category], 
        nil,
        0,
        100000,
        'price_asc',
        20,
        0
      )
    end
    
    puts "   ⏱️  Время: #{cached_time.real.round(3)} сек"
    puts "   ⚡ Кэш работает: #{(catalog_time.real / cached_time.real).round(1)}x быстрее!"
    puts
  end
  
  def check_indexes
    puts "📊 Тест 4: Проверка созданных индексов"
    
    # Проверяем критические индексы
    critical_indexes = [
      ['smiles', 'idx_smiles_json_order'],
      ['smiles', 'idx_smiles_created_at'], 
      ['products', 'idx_products_title'],
      ['products', 'idx_products_header'],
      ['products', 'idx_products_fulltext'],
      ['categories', 'idx_categories_title']
    ]
    
    puts "🔍 Проверяем наличие индексов:"
    
    critical_indexes.each do |table, index_name|
      begin
        result = ActiveRecord::Base.connection.execute(
          "SHOW INDEX FROM #{table} WHERE Key_name = '#{index_name}'"
        )
        
        if result.any?
          puts "   ✅ #{index_name} на таблице #{table}"
        else
          puts "   ❌ #{index_name} на таблице #{table} - ОТСУТСТВУЕТ!"
        end
      rescue => e
        puts "   ⚠️  Ошибка проверки #{index_name}: #{e.message}"
      end
    end
    puts
  end
  
  def run_all_tests
    check_indexes
    test_smiles_search
    test_product_search 
    test_catalog_performance
    
    puts "✅ ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ!"
    puts "💡 Рекомендация: Запустите миграцию 'rake db:migrate' для создания индексов"
  end
end

# Запуск тестов
if __FILE__ == $0
  begin
    PerformanceTest.new.run_all_tests
  rescue => e
    puts "❌ Ошибка в тестах: #{e.message}"
    puts e.backtrace.first(5)
  end
end
