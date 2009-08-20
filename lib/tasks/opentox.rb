desc "Install required gems"
task :install do
  puts `sudo gem install #{@gems}`
end

desc "Update gems"
task :update do
  puts `sudo gem update #{@gems}`
end

desc "Run tests"
task :test do
  load 'test.rb'
end

