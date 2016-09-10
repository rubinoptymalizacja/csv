require './csv.rb'
require './collection.rb'
require 'fileutils'

cvs_fn = "./rows_of_data.csv"


db = Collection.new({cvs_fn: cvs_fn})
puts db.header
puts db

