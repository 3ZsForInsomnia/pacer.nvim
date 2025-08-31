#!/bin/bash
nvim --headless -u NONE -i NONE -n \
  -c "lua package.path='./lua/?.lua;./lua/?/init.lua;./test/?.lua;'..package.path" \
  -c "lua require('test.init')" \
  -c "qa!"
