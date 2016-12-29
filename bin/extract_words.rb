#! /usr/bin/env ruby
# coding: utf-8

require 'find'

def get_words
  result = {}
  Find.find('./data/ruby') do |f|
    if FileTest.file?(f)
      source = File.read(f)
      source.scan(/\w+/).each do |w|
        result[w] ||= 0
        result[w] += 1
      end
    end
  end
  result
end

words = get_words

binding.pry

puts 'Finished!'
