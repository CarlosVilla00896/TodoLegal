class LawsController < ApplicationController
  layout 'law'
  # layout 'application', only: [:index]
  before_action :set_law, only: [:show, :edit, :update, :destroy]
  before_action :set_materias, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_editor!, only: [:index, :new, :edit, :create, :update, :destroy]

  # GET /laws
  # GET /laws.json
  def index
    @laws = Law.all.order(:law_access_id)
  end

  # GET /laws/1
  # GET /laws/1.json
  def show
    @stream = []
    @index_items = []
    @highlight_enabled = false
    @query = ""
    @articles_count = 0
    @has_articles_only = true
    @info_is_searched = false

    if params[:query]
      @tokens = params[:query].scan(/\w+|\W/)
      if @tokens.first == '/'
        articles = []
        @tokens.each do |token|
          if is_number token
            articles.push(token)
          end
        end
        params[:articles] = articles
        params[:query] = nil
      end
    end
    
    if params[:query] && params[:query] != ""
      @highlight_enabled = true
      @query = params[:query]
      @stream = @law.articles.search_by_body_highlighted_and_trimmed(params[:query]).with_pg_search_highlight.order(:position).sort_by { |article| article.position }
      @info_is_searched  = true
      @articles_count = @stream.size
    else
      i = 0
      book_iterator = 0
      title_iterator = 0
      chapter_iterator = 0
      section_iterator = 0
      subsection_iterator = 0
      article_iterator = 0

      @books = @law.books.order(:position)
      @titles = @law.titles.order(:position)
      @chapters = @law.chapters.order(:position)
      @sections = @law.sections.order(:position)
      @subsections = @law.subsections.order(:position)
      @articles = @law.articles.order(:position)

      @articles_count = @law.cached_articles_count

      go_to_position = nil

      if params[:articles] && params[:articles].size != 1
        @stream = @articles.where(number: params[:articles])
      else
        if params[:articles] && params[:articles].size == 1
          article = @articles.where('number LIKE ?', "%#{params[:articles].first}%").first
          if article
            go_to_position = @articles.where('number LIKE ?', "%#{params[:articles].first}%").first.position
          end
        end

        stream_size = @law.cached_books_count + @law.cached_titles_count + @law.cached_chapters_count + @law.cached_sections_count + @law.cached_subsections_count + @law.cached_articles_count
        while i < stream_size
          if book_iterator < @law.cached_books_count &&
              (@law.cached_titles_count == 0 ||
              (title_iterator < @law.cached_titles_count && @books[book_iterator].position < @titles[title_iterator].position)) &&
              (@law.cached_chapters_count == 0 ||
              (chapter_iterator < @law.cached_chapters_count && @books[book_iterator].position < @chapters[chapter_iterator].position)) &&
              (@law.cached_sections_count == 0 ||
              (section_iterator < @law.cached_sections_count && @books[book_iterator].position < @sections[section_iterator].position)) &&
              (@law.cached_subsections_count == 0 ||
              (subsection_iterator < @law.cached_subsections_count && @books[book_iterator].position < @subsections[subsection_iterator].position)) &&
              (@law.cached_articles_count == 0 ||
              (article_iterator < @law.cached_articles_count && @books[book_iterator].position < @articles[article_iterator].position))
            @stream.push @books[book_iterator]
            @index_items.push @books[book_iterator]
            book_iterator+=1
          elsif title_iterator < @law.cached_titles_count &&
              (@law.cached_chapters_count == 0 ||
              (chapter_iterator < @law.cached_chapters_count && @titles[title_iterator].position < @chapters[chapter_iterator].position)) &&
              (@law.cached_sections_count == 0 ||
              (section_iterator < @law.cached_sections_count && @titles[title_iterator].position < @sections[section_iterator].position)) &&
              (@law.cached_subsections_count == 0 ||
              (subsection_iterator < @law.cached_subsections_count && @titles[title_iterator].position < @subsections[subsection_iterator].position)) &&
              (@law.cached_articles_count == 0 ||
              (article_iterator < @law.cached_articles_count && @titles[title_iterator].position < @articles[article_iterator].position))
            @stream.push @titles[title_iterator]
            @index_items.push @titles[title_iterator]
            title_iterator+=1
          elsif chapter_iterator < @law.cached_chapters_count &&
              (@law.cached_sections_count == 0 ||
              (section_iterator < @law.cached_sections_count && @chapters[chapter_iterator].position < @sections[section_iterator].position)) &&
              (@law.cached_subsections_count == 0 ||
              (subsection_iterator < @law.cached_subsections_count && @chapters[chapter_iterator].position < @subsections[subsection_iterator].position)) &&
              (@law.cached_articles_count == 0 ||
              (article_iterator < @law.cached_articles_count && @chapters[chapter_iterator].position < @articles[article_iterator].position))
            @stream.push @chapters[chapter_iterator]
            @index_items.push @chapters[chapter_iterator]
            chapter_iterator+=1
          elsif section_iterator < @law.cached_sections_count &&
              (@law.cached_subsections_count == 0 ||
              (subsection_iterator < @law.cached_subsections_count && @sections[section_iterator].position < @subsections[subsection_iterator].position)) &&
              (@law.cached_articles_count == 0 ||
              (article_iterator < @law.cached_articles_count && @sections[section_iterator].position < @articles[article_iterator].position))
            @stream.push @sections[section_iterator]
            @index_items.push @sections[section_iterator]
            section_iterator+=1
          elsif subsection_iterator < @law.cached_subsections_count &&
              (@law.cached_articles_count == 0 ||
              (article_iterator < @law.cached_articles_count && @subsections[subsection_iterator].position < @articles[article_iterator].position))
            @stream.push @subsections[subsection_iterator]
            @index_items.push @subsections[subsection_iterator]
            subsection_iterator+=1
          else
            @stream.push @articles[article_iterator]
            if go_to_position && @articles[article_iterator] && go_to_position == @articles[article_iterator].position
              @go_to_article = article_iterator
            end
            article_iterator+=1
          end
          i+=1
        end
      end

      @has_articles_only = book_iterator == 0 && title_iterator == 0 && chapter_iterator == 0 && subsection_iterator == 0 && section_iterator == 0
    end

    @user_can_edit_law = current_user_is_editor
    @user_can_access_law = user_can_access_law @law, current_user
    if !@user_can_access_law
      @stream = @stream.take(5)
    end
  end

  # GET /laws/new
  def new
    @law = Law.new
  end

  # GET /laws/1/edit
  def edit
    @article_number = params[:article_number]
    if @article_number
      @article = @law.articles.where('number LIKE ?', "%#{@article_number}%").first
    else
      @article = @law.articles.first
    end

    # @law_materias = []
    # materia_tag_type = TagType.find_by_name("materia")
    # @all_materias = Tag.where(tag_type: materia_tag_type)
    # @law_materias = LawTag.where(law_id: @law.id, tag_id: @all_materias)

    creacion_tag_type = TagType.find_by_name("creacion")
    @all_creacions = Tag.where(tag_type: creacion_tag_type)
    @law_creacions = LawTag.where(law_id: @law.id, tag_id: @all_creacions)
    @law_modifications = @law.law_modifications
  end

  # POST /laws
  # POST /laws.json
  def create
    @law = Law.new(law_params)

    respond_to do |format|
      if @law.save
        format.html { redirect_to @law, notice: 'Law was successfully created.' }
        format.json { render :show, status: :created, location: @law }
      else
        format.html { render :new }
        format.json { render json: @law.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /laws/1
  # PATCH/PUT /laws/1.json
  def update
    respond_to do |format|
      if @law.update(law_params)
        format.html { redirect_to @law, notice: 'Law was successfully updated.' }
        format.json { render :show, status: :ok, location: @law }
      else
        format.html { render :edit }
        format.json { render json: @law.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /laws/1
  # DELETE /laws/1.json
  def destroy
    @law.destroy
    respond_to do |format|
      format.html { redirect_to laws_url, notice: 'Law was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_law
      @law = Law.find(params[:id])
    end

    def set_materias
      @law_materias = []
      materia_tag_type = TagType.find_by_name("materia")
      @all_materias = Tag.where(tag_type: materia_tag_type)
      @law_materias = LawTag.where(law_id: @law.id, tag_id: @all_materias)

      @tag = Tag.find_by(id: @law_materias[0].tag_id)
      lawTags = LawTag.where(tag_id: @tag.id)
      
      @laws_array = []
      counter = 0
      while counter < lawTags.size
        law = Law.find_by(id: lawTags[counter].law_id)
        if law
          @laws_array[counter] = law
        end
        counter+=1
      end

    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def law_params
      params.require(:law).permit(:name, :modifications, :creation_number)
    end

    def user_can_access_law law, user
      law_access = law.law_access
      if law_access
        if law_access.name == "Pro"
          if !user_is_pro user
            return false
          end
        end
        if law_access.name == "Básica"
          if !current_user
            return false
          end
        end
      end
      return true
    end
end
