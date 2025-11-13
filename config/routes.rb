Rails.application.routes.draw do
  root 'pages#home'
  
  get 'pages/home'
  
  resources :memes do
    collection do
      get :random
      get :search
      get :trending
    end
  end
  
  resources :auth, only: [] do
    collection do
      get :login
      get :signup
      post :callback
    end
  end
  
  resources :likes, only: [:create, :destroy]
  resources :users, only: [:show] do
    member do
      get :profile
    end
  end
end
