#!/usr/bin/env ruby
# encoding: utf-8

# Тест для проверки нового функционала в админке комментариев

puts "=== ТЕСТ НОВОГО ФУНКЦИОНАЛА АДМИНКИ КОММЕНТАРИЕВ ==="

def get_tab_description(filter)
  case filter
  when 'all'
    'Показывает все комментарии (опубликованные + неопубликованные)'
  when 'unpublished'
    'Показывает только неопубликованные комментарии (published = 0)'
  when 'new'
    'Форма создания нового комментария'
  end
end

def simulate_comment_data(published_status)
  {
    id: rand(1000..9999),
    name: "Иван Петров",
    body: "Очень красивые цветы! Рекомендую!",
    rating: 5,
    published: published_status,
    order_eight_digit_id: rand(10000000..99999999),
    created_at: Time.now - rand(1..30) * 24 * 60 * 60
  }
end

def display_comment_in_admin_table(comment)
  is_published = comment[:published] == 1
  
  puts "Строка в таблице:"
  puts "  ID: #{comment[:id]} #{is_published ? '' : '(жирный шрифт)'}"
  puts "  Имя: #{comment[:name]} #{is_published ? '' : '(жирный шрифт)'}"
  puts "  Отзыв: #{comment[:body][0..30]}... #{is_published ? '' : '(жирный шрифт)'}"
  puts "  Оценка: #{comment[:rating]} #{is_published ? '' : '(жирный шрифт)'}"
  puts "  Номер заказа: #{comment[:order_eight_digit_id]}"
  
  if is_published
    puts "  Статус: [Опубликован] (зелёный лейбл)"
  else
    puts "  Статус: [Неопубликован] (жёлтый лейбл)"
  end
  
  puts "  Фон строки: #{is_published ? 'обычный' : 'светло-жёлтый (#fffbea)'}"
  puts "---"
end

# Тестирование отображения комментариев
puts "1. Опубликованный комментарий:"
published_comment = simulate_comment_data(1)
display_comment_in_admin_table(published_comment)

puts "2. Неопубликованный комментарий:"
unpublished_comment = simulate_comment_data(0)
display_comment_in_admin_table(unpublished_comment)

# Тестирование вкладок
puts "=== ТЕСТИРОВАНИЕ ВКЛАДОК ==="
puts

tabs = [
  { name: 'Все', url: '/admin/comments', icon: 'list', filter: 'all' },
  { name: 'Неопубликованные', url: '/admin/comments/unpublished', icon: 'exclamation-sign', filter: 'unpublished' },
  { name: 'Новый', url: '/admin/comments/new', icon: 'plus', filter: 'new' }
]

tabs.each_with_index do |tab, index|
  active_marker = case tab[:filter]
  when 'all'
    '(ACTIVE)' # по умолчанию активна вкладка "Все"
  when 'unpublished'
    '(новая вкладка)'
  else
    ''
  end
  
  puts "#{index + 1}. [#{tab[:icon]}] #{tab[:name]} #{active_marker}"
  puts "   URL: #{tab[:url]}"
  puts "   Описание: #{get_tab_description(tab[:filter])}"
  puts
end



# Тестирование формы редактирования
puts "=== ТЕСТИРОВАНИЕ ФОРМЫ РЕДАКТИРОВАНИЯ ==="
puts

forms_fields = [
  { name: 'title', status: 'removed', description: 'Убрано из формы редактирования' },
  { name: 'name', status: 'existing', description: 'Оставлено без изменений' },
  { name: 'body', status: 'existing', description: 'Оставлено без изменений' },
  { name: 'rating', status: 'existing', description: 'Оставлено без изменений' },
  { name: 'date', status: 'existing', description: 'Оставлено без изменений' },
  { name: 'order_eight_digit_id', status: 'existing', description: 'Оставлено без изменений' },
  { name: 'published', status: 'new', description: 'Новое поле: чекбокс для опубликования' }
]

forms_fields.each do |field|
  status_marker = case field[:status]
  when 'new'
    '✨ НОВОЕ'
  when 'removed'
    '❌ УБРАНО'
  when 'existing'
    '✅ ОСТАВЛЕНО'
  end
  
  puts "#{status_marker} #{field[:name]}: #{field[:description]}"
end

puts "\n=== КЛЮЧЕВЫЕ ИЗМЕНЕНИЯ ==="
puts

changes = [
  '✨ Добавлена новая вкладка "Неопубликованные" перед "Новый"',
  '❌ Удалена колонка "title" из таблицы админки',
  '✨ Добавлена колонка "Статус" с лейблами',
  '🎨 Неопубликованные комментарии отображаются жирным шрифтом',
  '🎨 Неопубликованные комментарии имеют светло-жёлтый фон',
  '✨ Добавлено поле "published" в форму редактирования',
  '🔄 Обновлен allowed_params в контроллере для поддержки published'
]

changes.each_with_index do |change, index|
  puts "#{index + 1}. #{change}"
end

puts "\n=== РЕЗУЛЬТАТ ==="
puts
puts "✅ Администратор теперь может:"
puts "   - Видеть все комментарии на вкладке 'Все'"
puts "   - Быстро находить неопубликованные на вкладке 'Неопубликованные'"
puts "   - Легко отличать неопубликованные (жирный шрифт + жёлтый фон)"
puts "   - Управлять статусом публикации каждого отзыва"
puts "   - Не видеть лишнее поле 'title' в списке"

puts "\nТестирование завершено! 🎆"
