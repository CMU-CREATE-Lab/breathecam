# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_breathecam_session',
  :secret      => '62fbda0dacf03749d8b013fc885ad15b818382870259c85c8fdf05e8525705fbebec98f97b48ff36ade6a9b2113b629a7db9ceeb70fe20045aee20dd3e86fbe5'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
