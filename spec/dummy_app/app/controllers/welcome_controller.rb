class WelcomeController < ApplicationController
  def index
    session[:uid] = '123'
  end
end
