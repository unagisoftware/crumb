Rails.application.routes.draw do
  mount Crumb::Engine => "/crumb"
end
