# encoding: utf-8
# ОПТИМИЗИРОВАННАЯ ВЕРСИЯ ADMIN PRODUCTS CONTROLLER
# Основные улучшения:
# 1. Оптимизирован fuzzy search без Product.all
# 2. Добавлено кэширование для частых запросов
# 3. Улучшена пагинация
# 4. Оптимизированы joins для скорости

# ОПТИМИЗИРОВАННЫЕ МЕТОДЫ ПОИСКА
module OptimizedSearch
  # Оптимизированный fuzzy поиск без загрузки всех продуктов
  def self.fuzzy_search_products(query, limit = 128)
    return [] if query.nil? || query.length < 3
    
    # Кэширование результатов поиска
    cache_key = "fuzzy_search_#{Digest::MD5.hexdigest(query.to_s)}_#{limit}"
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      
      # Сначала пробуем обычный SQL LIKE поиск
      sql_results = Product.where("header LIKE ? OR title LIKE ?", 
                                  "%#{query}%", "%#{query}%")
                           .limit(limit)
                           .to_a
      
      # Если нашли точные совпадения, возвращаем их
      return sql_results if sql_results.size >= 5
      
      # Иначе делаем fuzzy search по ограниченному набору
      require 'fuzzystringmatch'
      jarow = FuzzyStringMatch::JaroWinkler.create(:pure)
      
      # Загружаем только header и id для оптимизации
      candidates = Product.select(:id, :header)
                          .where("LENGTH(header) BETWEEN ? AND ?", 
                                 query.length - 10, query.length + 30)
                          .limit(1000) # Ограничиваем кандидатов
      
      fuzzy_results = candidates
        .map { |product| [product, jarow.getDistance(product.header, query)] }
        .select { |product, distance| distance > 0.5 }
        .sort_by { |product, distance| -distance }
        .map(&:first)
        .take(limit)
      
      # Загружаем полные объекты только для найденных
      return Product.where(id: fuzzy_results.map(&:id)).to_a
    end
  end
end

# ОПТИМИЗИРОВАННЫЙ КОНТРОЛЛЕР
Rozario::Admin.controllers :products_optimized do

  # Оптимизированный список товаров
  get :index do
    # Кэширование списка категорий
    @categories = Rails.cache.fetch('admin_categories_list', expires_in: 1.hour) do
      Category.select(:title, :id).order(:title).to_a
    end
    
    # Оптимизированная пагинация с includes
    @products = Product.includes(:categories, :complects)
                       .order('id desc')
                       .paginate(page: params[:page], per_page: 20)
    
    render 'products/index'
  end

  # Оптимизированный поиск
  post :search do
    query = params[:query].to_s.strip
    
    if query.length >= 3
      @products = OptimizedSearch.fuzzy_search_products(query, 128)
      
      if @products.empty?
        flash[:error] = "Ничего не найдено :("
        redirect back
      else
        render 'products/search'
      end
    else
      flash[:error] = "Короткий запрос :("
      redirect back
    end
  end

  # Оптимизированный поиск по категории
  get :category do
    if params[:category_id].blank?
      redirect url(:products, :index)
    else
      ids = params[:category_id].map(&:to_i)
      
      # Оптимизированный JOIN с includes
      @products = Product.joins(:categories)
                         .includes(:categories, :complects)
                         .where(categories: { id: ids })
                         .order('id desc')
                         .paginate(page: params[:page], per_page: 20)
      
      @categories = Rails.cache.fetch('admin_categories_list', expires_in: 1.hour) do
        Category.select(:title, :id).order(:title).to_a
      end
      
      render 'products/index'
    end
  end

  # Оптимизированное создание товара
  get :new do
    @product = Product.new
    
    # Кэширование данных для формы
    @categories = Rails.cache.fetch('admin_categories_list', expires_in: 1.hour) do
      Category.select(:title, :id).order(:title).to_a
    end
    
    @complects = Rails.cache.fetch('admin_complects_list', expires_in: 1.hour) do
      Complect.select(:title, :id).order(:title).to_a
    end
    
    render 'products/new'
  end

  # Оптимизированное редактирование
  get :edit, with: :id do
    @product = Product.includes(:categories, :complects).find(params[:id])
    
    # Кэширование данных для формы
    @categories = Rails.cache.fetch('admin_categories_list', expires_in: 1.hour) do
      Category.select(:title, :id).order(:title).to_a
    end
    
    @complects = Rails.cache.fetch('admin_complects_list', expires_in: 1.hour) do
      Complect.select(:title, :id).order(:title).to_a
    end
    
    render 'products/edit'
  end

  # Обновление с очисткой кэша
  put :update, with: :id do
    @product = Product.find(params[:id])
    
    if @product.update_attributes(product_params)
      # Очистка связанных кэшей
      Rails.cache.delete_matched("smiles_product_#{@product.id}_*")
      Rails.cache.delete_matched("product_#{@product.id}_*")
      
      flash[:notice] = 'Товар успешно обновлен.'
      redirect url(:products, :edit, id: @product.id)
    else
      render 'products/edit'
    end
  end

  # Удаление с очисткой кэша
  delete :destroy, with: :id do
    @product = Product.find(params[:id])
    product_id = @product.id
    
    if @product.destroy
      # Очистка всех связанных кэшей
      Rails.cache.delete_matched("smiles_product_#{product_id}_*")
      Rails.cache.delete_matched("product_#{product_id}_*")
      Rails.cache.delete('admin_categories_list')
      
      flash[:notice] = 'Товар успешно удален.'
    else
      flash[:error] = 'Ошибка при удалении товара.'
    end
    
    redirect url(:products, :index)
  end

  private

  def product_params
    params.require(:product).permit(:title, :header, :description, :price, 
                                   :image, category_ids: [], complect_ids: [])
  end
end
