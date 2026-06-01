Crumb::Engine.routes.draw do
  resources :deploys, only: [ :index, :show, :create, :update ]
end
