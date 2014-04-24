#!/bin/bash
cd ..
RAILS_ENV=production bundle exec rake assets:precompile
cd tmp
touch restart.txt
