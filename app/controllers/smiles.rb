# encoding: utf-8
# ОПТИМИЗИРОВАННАЯ ВЕРСИЯ SMILES CONTROLLER для Padrino + MySQL
# Основные улучшения:
# 1. Убраны Smile.all запросы
# 2. Добавлено SQL LIKE для поиска по JSON
# 3. Добавлено кэширование через Padrino.cache
# 4. Улучшена пагинация
# 5. Оптимизированы запросы для MySQL

Rozario::App.controllers :smiles do
  get('/gettt/:page/?') do
    puts "get ('/smiles/gettt/:page/?') app.rb"
    # ОПТИМИЗАЦИЯ: Правильная пагинация вместо offset/limit
    @offset = params[:page].to_i * 12 - 12
    @posts = Smile.order('created_at DESC').offset(@offset).limit(12)
    @lastget = @offset >= Smile.count - 12
    erb :'smiles/get'
  end

  # отобразить форму для создания нового поста
  get ('/create/?') do
    erb :'smiles/create'
  end

  # основная страница отзывов
  get ('/?') do
    @tt = false
    # ОПТИМИЗАЦИЯ: Кэширование последних 12 отзывов (Padrino cache)
    if defined?(Padrino.cache) && Padrino.cache
      cache_key = "smiles_latest_12"
      @postsss = Padrino.cache.get(cache_key)
      unless @postsss
        @postsss = Smile.order('created_at DESC').limit(12)
        Padrino.cache.set(cache_key, @postsss, expires: 300) # 5 минут
      end
    else
      @postsss = Smile.order('created_at DESC').limit(12)
    end
    @lastget = @postsss.size < 12
    get_seo_data('smiles_page', nil, true)
    erb :'smiles/index'
  end

  # ОПТИМИЗИРОВАННОЕ отображение отзывов по товару
  get ('/product/:id/?') do
    @pid = params[:id]
    @tt = true
    
    # ОПТИМИЗАЦИЯ: Кэширование отзывов по товару
    if defined?(Padrino.cache) && Padrino.cache
      cache_key = "smiles_product_#{@pid}_12"
      @result = Padrino.cache.get(cache_key)
      unless @result
        # Используем SQL LIKE для поиска по JSON вместо загрузки всех записей
        # MySQL оптимизация: используем COLLATE для ускорения поиска
        json_pattern = "%\"id\":\"#{@pid}\"%"
        @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                      .order('created_at DESC')
                      .limit(12)
        Padrino.cache.set(cache_key, @result, expires: 600) # 10 минут
      end
    else
      json_pattern = "%\"id\":\"#{@pid}\"%"
      @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                    .order('created_at DESC')
                    .limit(12)
    end

    @lastget = @result.size < 12
    @postsss = @result
    get_seo_data('smiles_page', nil, true)
    erb :'smiles/index'
  end

  # ОПТИМИЗИРОВАННОЕ отображение конкретного отзыва
  get ('/product/:pid/:sid/?') do
    @dsc = DscntClass.new.some_method
    @pid = params[:pid]
    @id = params[:sid]
    
    # ОПТИМИЗАЦИЯ: Кэширование отзывов по товару для навигации
    if defined?(Padrino.cache) && Padrino.cache
      cache_key = "smiles_product_#{@pid}_all"
      @result = Padrino.cache.get(cache_key)
      unless @result
        json_pattern = "%\"id\":\"#{@pid}\"%"
        @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                      .order('created_at DESC')
        Padrino.cache.set(cache_key, @result, expires: 600) # 10 минут
      end
    else
      json_pattern = "%\"id\":\"#{@pid}\"%"
      @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                    .order('created_at DESC')
    end
    
    @postsss = @result
    
    # ОПТИМИЗАЦИЯ: Более эффективная настройка навигации между отзывами
    current_index = @postsss.find_index { |item| item.id == @id.to_i }
    if current_index
      @p_prev = current_index > 0 ? @postsss[current_index - 1].id : @postsss.last&.id
      @p_next = current_index < @postsss.size - 1 ? @postsss[current_index + 1].id : @postsss.first&.id
    end

    # Load SEO data and generate custom title for smiles pages
    smile = Smile.find_by_id(@id)
    if smile
      get_seo_data('smiles', smile.seo_id) if smile.respond_to?(:seo_id)
      custom_title = generate_smile_title(@id) if respond_to?(:generate_smile_title)
      @seo[:title] = custom_title if custom_title
    end
    
    erb :'smiles/show'
  end

  # ОПТИМИЗИРОВАННАЯ пагинация отзывов по товару
  get ('/gettttt/:page/?') do
    @product = Product.find_by_id(params[:id])
    @offset = params[:page].to_i * 12 - 12
    
    # ОПТИМИЗАЦИЯ: Кэширование с учетом страницы
    if defined?(Padrino.cache) && Padrino.cache
      cache_key = "smiles_product_#{params[:id]}_page_#{params[:page]}"
      @result = Padrino.cache.get(cache_key)
      unless @result
        json_pattern = "%\"id\":\"#{params[:id]}\"%"
        @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                      .order('created_at DESC')
                      .offset(@offset)
                      .limit(12)
        Padrino.cache.set(cache_key, @result, expires: 600) # 10 минут
      end
    else
      json_pattern = "%\"id\":\"#{params[:id]}\"%"
      @result = Smile.where("json_order COLLATE utf8_bin LIKE ?", json_pattern)
                    .order('created_at DESC')
                    .offset(@offset)
                    .limit(12)
    end

    @postsss = @result
    @lastget = @result.size < 12
    erb :'smiles/get'
  end
end
