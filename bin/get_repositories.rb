#! /usr/bin/env ruby
# coding: utf-8

require 'csv'
require 'octokit'

RETRY_SECONDS_MAP = {
  Octokit::TooManyRequests => 60,
  Octokit::AbuseDetected => 60 * 5,
}
Language = Struct.new(:name, :extensions)

def retry_process(&block)
  block.call()

rescue Octokit::Forbidden => e
  sleep_seconds = RETRY_SECONDS_MAP[e.class]
  raise e if sleep_seconds.nil?

  puts("Exception Occurred! [%s] Retry at after %d seconds..." % [e.class.to_s, sleep_seconds])
  sleep sleep_seconds
  retry
end

def get_repositories(oct, lang)
  retry_process do
    res = oct.search_repos('language:%s' % lang.name)
    res[:items]
  end
end

def get_codes(oct, repo, lang)
  retry_process do
    extensions = lang.extensions.map{|e| 'extension:%s' % e}.join(' ')
    query = '%s language:%s size:>%d %s' % [repo[:full_name], lang.name, 1000, extensions]
    puts "\t%s" % query
    oct.search_code(query)[:items]
  end
end
  
def get_content(oct, code)
  retry_process do
    puts "\t%s %s" % [code[:repository][:full_name], code[:path]]
    oct.contents(code[:repository][:id], {path: code[:path]})
  end
end

def main
  
  script_dir = File.expand_path(File.dirname(__FILE__))

  csv = CSV.table(script_dir + '/languages.csv')

  puts 'Load Languages.'
  langs = csv.map do |row|
    Language.new(row[:name], row[:name].split('|'))
  end

  oct = Octokit::Client.new(login: 'NomadBlacky', password: ENV['OCTOKIT_PASSWORD'])

  langs.map do |lang|
    puts 'Get %s repositories.' % lang.name
    repos = get_repositories(oct, lang)

    puts 'Get %s codes.' % lang.name
    codes = repos.flat_map{|repo| get_codes(oct, repo, lang)}
      
    puts 'Get %s contents.' % lang.name
    contents = codes.map{|code| get_content(oct, code)}

    puts 'Write download urls of %s.' % lang.name
    File.open('dl/%s' % lang.name, 'w') do |f|
      contents.each{|c| f.puts(c[:download_url])}
    end
  end

  puts "Finished!"

end

main()
