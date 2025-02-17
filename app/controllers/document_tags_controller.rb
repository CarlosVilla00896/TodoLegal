class DocumentTagsController < ApplicationController
    before_action :set_document_tag, only: [:show, :edit, :update, :destroy]
    before_action :authenticate_editor!, only: [:show, :new, :edit, :create, :update, :destroy]
  
    # GET /document_tags/1
    # GET /document_tags/1.json
    def show
    end
  
    # GET /document_tags/new
    def new
      @document_tag = DocumentTag.new
    end
  
    # GET /document_tags/1/edit
    def edit
    end
  
    # POST /document_tags
    # POST /document_tags.json
    def create
      redirect_url = params[:document_tag][:return_to]
      if document_tag_params[:tag_id].to_i != 0
        @document_tag = DocumentTag.new(document_id: document_tag_params[:document_id], tag_id: document_tag_params[:tag_id])
      else
        @tag_type = TagType.find_by(name: document_tag_params[:tag_type])
        @new_tag = Tag.create(name: document_tag_params[:tag_id], tag_type_id: @tag_type.id)
        @document_tag = DocumentTag.new(document_id: document_tag_params[:document_id], tag_id: @new_tag.id)
      end

      respond_to do |format|
        if @document_tag.save
          if redirect_url.present?
            #create new datapoint
            datapoint_type = ""

            tag_type = TagType.find_by(name: @document_tag.tag.tag_type.name)

            if tag_type.name == "materia"
              datapoint_type = DatapointType.find_by(name: "Materia")
            elsif tag_type.name == "Tema"
              datapoint_type = DatapointType.find_by(name: "Tema")
            elsif tag_type.name == "Tipo de Acto"
              datapoint_type = DatapointType.find_by(name: "Tipo de Acto")
            end

            if datapoint_type.present?
              datapoint = Datapoint.create(document_id: @document_tag.document.id, document_tag_id: @document_tag.id, datapoint_type_id: datapoint_type.id, status: :pendiente, is_active: true, is_empty_field: false) 
            end

            flash.now[:notice] = 'Cambios guardados automaticamente'
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace(
                  "new_tag_#{@document_tag.tag.tag_type.name}_false", 
                  partial: "documents/edit_tag_table", 
                  locals: {
                    document: @document_tag.document, 
                    tag_name: @document_tag.tag.tag_type.name, 
                    issuer: false 
                  }
                ),
                turbo_stream.replace(
                  "autosave_flash_tags_#{@document_tag.tag.tag_type.name.parameterize}_false", 
                  partial: "layouts/flash", 
                  locals: { 
                    alert_origin: "tags",
                    alert_type: "success",
                    remove_alert: "true",
                    fade_timeout: "2000" 
                  }
                )
              ]
            end
            format.html { redirect_to edit_document_path(@document_tag.document, return_to: redirect_url), notice: 'Se ha añadido el tag exitosamente.' }
          else
            flash.now[:notice] = 'Cambios guardados automaticamente'
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace(
                  "new_tag_#{@document_tag.tag.tag_type.name}_false", 
                  partial: "documents/edit_tag_table", 
                  locals: {
                    document: @document_tag.document, 
                    tag_name: @document_tag.tag.tag_type.name, 
                    issuer: false 
                  }
                ),
                turbo_stream.replace(
                  "autosave_flash_tags_#{@document_tag.tag.tag_type.name.parameterize}_false", 
                  partial: "layouts/flash", 
                  locals: { 
                    alert_origin: "tags",
                    alert_type: "success",
                    remove_alert: "true",
                    fade_timeout: "2000" 
                  }
                )
              ]
            end
            format.html { redirect_to edit_document_path(@document_tag.document), notice: 'Se ha añadido el tag exitosamente.' }
          end
          
          format.json { render :show, status: :created, location: @document_tag.document }
        else
          flash.now[:notice] = 'Error al guardar el tag, intenta de nuevo'
          format.turbo_stream do
            render turbo_stream: 
              turbo_stream.replace(
                "autosave_flash_tags_#{@document_tag.tag.tag_type.name.parameterize}_false", 
                partial: "layouts/flash", 
                locals: { 
                  alert_origin: "tags",
                  alert_type: "danger",
                  remove_alert: "true",
                  fade_timeout: "2000" 
                }
              )
          end
          format.html { render :new }
          format.json { render json: @document_tag.errors, status: :unprocessable_entity }
        end
      end
    end
  
    # PATCH/PUT /document_tags/1
    # PATCH/PUT /document_tags/1.json
    def update
      respond_to do |format|
        if @document_tag.update(document_tag_params)
          format.html { redirect_to @document_tag, notice: 'Se ha actualizado la materia exitosamente.' }
          format.json { render :show, status: :ok, location: @document_tag }
        else
          format.html { render :edit }
          format.json { render json: @document_tag.errors, status: :unprocessable_entity }
        end
      end
    end
  
    # DELETE /document_tags/1
    # DELETE /document_tags/1.json
    def destroy
      redirect_url = params[:return_to]
      document = @document_tag.document
      @document_tag.destroy
      respond_to do |format|
        if redirect_url.present?
          format.html { redirect_to edit_document_path(document, return_to: redirect_url), notice: 'Se ha eliminado el tag exitosamente.' }
        else
          format.html { redirect_to edit_document_path(document), notice: 'Se ha eliminado el tag exitosamente.' }
        end
        format.json { head :no_content }
      end
    end
  
    private
      # Use callbacks to share common setup or constraints between actions.
      def set_document_tag
        @document_tag = DocumentTag.find(params[:id])
      end
  
      # Never trust parameters from the scary internet, only allow the white list through.
      def document_tag_params
        params.require(:document_tag).permit(:document_id, :tag_id, :tag_type, :return_to)
      end
end
  