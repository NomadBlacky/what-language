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

def main
  
  script_dir = File.expand_path(File.dirname(__FILE__))

  csv = CSV.table(script_dir + '/languages.csv')

  puts 'Load Languages.'
  langs = csv.map do |row|
    Language.new(row[:name], row[:extension].split('|'))
  end

  oct = Octokit::Client.new(login: 'NomadBlacky', password: ENV['OCTOKIT_PASSWORD'])

  langs.map do |lang|
    puts 'Get %s repositories.' % lang.name
    repos = get_repositories(oct, lang)

    puts 'Get %s archives.' % lang.name
    repos.take(5).each do |repo|
      system('mkdir -p ./repos/%s' % lang.name)
      url = repo[:archive_url].gsub('{archive_format}', 'tarball').gsub('{/ref}', '')
      puts "\t%s" % repo[:full_name]
      system('curl -sL %s > ./repos/%s/%s.tar.gz' % [url, lang.name, repo[:id]])
    end
  end

  puts "Finished!"

end

main()
