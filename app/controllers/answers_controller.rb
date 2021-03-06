class AnswersController < ApplicationController
  before_action :set_answer, only: [:show, :edit, :update, :destroy]

  def index
    @answers = Answer.all
  end

  def show
  end

  def new
    # @question = Question.find(params[:question_id])
    @answer = Answer.new
  end

  def edit
  end

  def create
    @answer = Answer.new
    @answer.content = params[:content]
    @answer.user_id = current_user.id
    @answer.question = Question.find(params[:answer][:question_id])

    if current_user == nil
      redirect_to new_user_registration_path
    else
      # @answer.user_id = current_user.id
      # @answer.question_id = @question.id
    end

   @answer.save!
    # @answer.question = @question

    # respond_to do |format|
    #   if @answer.save
    #     format.html { redirect_to questions_path }
    #     format.json { render :show, status: :created, location: @question }
    #   else
    #     format.html { render :new }
    #     format.json { render json: @answer.errors, status: :unprocessable_entity }
    #   end
    # end
  end

  def update
    respond_to do |format|
      if @answer.update(answer_params)
        format.html { redirect_to @answer, notice: 'Answer was successfully updated.' }
        format.json { render :show, status: :ok, location: @answer }
      else
        format.html { render :edit }
        format.json { render json: @answer.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @answer.destroy
    respond_to do |format|
      format.html { redirect_to answers_url, notice: 'Answer was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_answer
      @answer = Answer.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def answer_params
      params.require(:answer).permit(:content, :user_id, :question_id)
      # params.fetch(:answer, {})
    end
end
