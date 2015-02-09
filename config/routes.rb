require 'sidekiq/web'

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

  # resources :configuration_objects, only: [:show]

  get '/object_tree_format/:id' => 'object_tree_formats#get_object_tree'
  get '/diff_tree_format/:id'   => 'object_tree_formats#get_diff_tree'
  
  get '/enviroment_logs/:id' => 'workers#get_env_logs'

  mount Sidekiq::Web, at: '/sidekiq'
  
  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
