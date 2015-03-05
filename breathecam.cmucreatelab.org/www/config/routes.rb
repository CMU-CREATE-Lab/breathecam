Breathecam::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # TODO: This can probably be combined into one statement.
  root :to => "embeds#index", :constraints => { :subdomain  => "ecam" }
  match '(*path)/:location' => "embeds#index", :constraints => { :subdomain  => "ecam" }

  root :to => 'home#index'

  match 'embeds/' => 'embeds#index', :defaults => { :location => "heinz" }
  match 'embeds/:location' => 'embeds#index', :defaults => { :location => "heinz" }

  match 'achd/' => 'achd#index', :defaults => { :location => "heinz" }
  match 'achd/:location' => 'achd#index', :defaults => { :location => "heinz" }

  post '/location_pinger' => 'locations_handler#receive_data'
  post '/upload' => 'locations_handler#upload'
  match '/upload', :controller => 'locations_handler', :action => 'upload', :constraints => {:method => 'OPTIONS'}

  # Legacy route
  match 'locations/' => 'locations#index', :defaults => { :location => "heinz" }
  match 'locations/:location' => 'locations#index'

  #static routes
  match ':action', :controller => "static"

end
