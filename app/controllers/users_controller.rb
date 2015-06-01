class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :edit, :update, :destroy, :complete]
  before_filter :ensure_signup_complete, only: [:new, :create, :update, :destroy]

  # GET /:username.:format
  def show
    @unfollowers = @user.unfollowers.where(updated: 1).paginate(:page => params[:page])
  end

  # PATCH/PUT /:username.:format
  def update
    respond_to do |format|
      if @user.update(user_params)
        sign_in(@user == current_user ? @user : current_user, :bypass => true)
        format.html { redirect_to @user, notice: 'Your profile was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET/PATCH /:username/complete
  def complete
    if request.patch? && params[:user]
      if @user.update(user_params)
        # load all followers uid
        SyncWorker.perform_async(current_user.id)
        sign_in(@user, :bypass => true)
        redirect_to @user, notice: 'Your profile was successfully activated.'
      else
        flash[:error] = "Unable to complete signup due: #{@user.errors.full_messages.to_sentence}"
      end
    end
  end

  # DELETE /:username.:format
  def destroy
    reset_session
    DeleteUserWorker.perform_async(@user.id)
    respond_to do |format|
      format.html { redirect_to root_url , notice: 'Your account was successfully deleted.'}
      format.json { head :no_content }
    end
  end

  # GET /loadmore
  def loadmore
    @stop_loading = false
    @unfollowers = current_user.unfollowers.where(updated: 1).paginate(:page => params[:page])
    if @unfollowers.last and current_user.unfollowers.where(updated: 1).last.id == @unfollowers.last.id
      @stop_loading = true
    end
  end

  # GET /loadstats
  def loadstats
    @unfollowers = current_user.unfollowers.where(updated: 1)
    @today = @unfollowers.where("created_at >= ?", Time.zone.now.beginning_of_day)
    @week = @unfollowers.where("created_at >= ?", 1.week.ago)

    
    
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    accessible = [:name, :email, :username, :description, :name, :notification]
    accessible << [:password, :password_confirmation] unless params[:user][:password].blank?
    params.require(:user).permit(accessible)
  end
end
