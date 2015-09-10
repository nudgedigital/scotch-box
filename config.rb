#!/usr/bin/env ruby
require 'yaml'

cnf = YAML::load_file(File.join(__dir__, 'config.yaml'))
domain = ARGV[0]
puts cnf['config'][domain]['root'] unless !cnf['config'].include? domain
