# encoding: utf-8
# Мониторинг производительности для Падрино приложения
# Отслеживает критические операции и их время выполнения

require 'benchmark'

class PerformanceMonitor
  
  def self.log_slow_operation(operation_name, threshold_ms = 1000)
    start_time = Time.now
    start_queries = query_count
    
    result = yield
    
    end_time = Time.now
    end_queries = query_count
    
    execution_time_ms = ((end_time - start_time) * 1000).round(2)
    queries_executed = end_queries - start_queries
    
    if execution_time_ms > threshold_ms
      log_message = "⚠️  SLOW OPERATION: #{operation_name} took #{execution_time_ms}ms (#{queries_executed} SQL queries)"
      Padrino.logger.warn(log_message)
      puts log_message if Padrino.env != :production
    else
      log_message = "✅ #{operation_name}: #{execution_time_ms}ms (#{queries_executed} queries)"
      Padrino.logger.info(log_message) if Padrino.env == :development
    end
    
    result
  end
  
  def self.log_search_performance(search_term, results_count, execution_time_ms)
    if execution_time_ms > 500 # 500ms порог
      Padrino.logger.warn("🔍 SLOW SEARCH: '#{search_term}' returned #{results_count} results in #{execution_time_ms}ms")
    else
      Padrino.logger.info("🔍 Search: '#{search_term}' -> #{results_count} results (#{execution_time_ms}ms)")
    end
  end
  
  def self.log_catalog_performance(params, results_count, execution_time_ms, cached = false)
    cache_status = cached ? "[CACHED]" : "[DB]"
    subdomain_info = params[:subdomain]&.name || 'unknown'
    
    if execution_time_ms > 1000 # 1 секунда порог
      Padrino.logger.warn("📋 SLOW CATALOG #{cache_status}: #{subdomain_info} returned #{results_count} products in #{execution_time_ms}ms")
    else
      Padrino.logger.info("📋 Catalog #{cache_status}: #{subdomain_info} -> #{results_count} products (#{execution_time_ms}ms)")
    end
  end
  
  private
  
  def self.query_count
    # Пытаемся получить количество запросов из ActiveRecord
    if defined?(ActiveRecord::Base.connection.query_cache) && ActiveRecord::Base.connection.respond_to?(:query_cache_enabled)
      # Для новых версий ActiveRecord
      ActiveRecord::Base.connection.query_cache.size rescue 0
    else
      # Fallback - используем 0, чтобы не ломать приложение
      0
    end
  end
end

# Расширение для моделей - автоматический мониторинг медленных запросов
module PerformanceExtensions
  extend ActiveSupport::Concern
  
  module ClassMethods
    def with_performance_monitoring(operation_name, threshold_ms = 1000)
      PerformanceMonitor.log_slow_operation(operation_name, threshold_ms) { yield }
    end
  end
end

# Подключаем к ActiveRecord моделям
ActiveRecord::Base.include(PerformanceExtensions) if defined?(ActiveRecord::Base)
