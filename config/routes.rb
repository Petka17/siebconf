Rails.application.routes.draw do

  root 'static_pages#home'

  resources :users
  resources :sessions, only: [:new, :create, :destroy]

  match '/signup',  to: 'users#new',                  via: 'get'
  match '/signin',  to: 'sessions#new',               via: 'get'
  match '/signout', to: 'sessions#destroy',           via: 'delete'

  resources :settings, only: [:index, :show, :new, :create] do
    resources :setting_values, only: [:new, :create, :edit, :update, :destroy]
  end
  
  resources :environments do
    collection do
      get  'edit_order'
      post 'update_order'
    end
    
    member do
      get  'edit_server_roles'
      post 'update_server_roles'
    end

    resources :servers, only: [:new, :create, :edit, :update, :destroy]
   
    resources :siebel_configurations, only: [:index, :show, :edit, :update] do
      collection do
        get  'new_pull'
        post 'create_pull'
      end

      member do
        get  'get_object_index'
        get  'new_push'
        post 'create_push'
      end 
    end
  end

  get '/object_tree_format/:id' => 'object_tree_formats#get_object_tree'
  get '/diff_tree_format/:id'   => 'object_tree_formats#get_diff_tree'
  
  get '/enviroment_logs/:id' => 'workers#get_env_logs'

  # match "/delayed_job" => DelayedJobWeb, :anchor => false, via: [:get, :post]
end
