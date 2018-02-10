require 'sinatra'
require 'json'
require 'fileutils'

configure { set :server, :thin }

HOMEDIR = "/Users/aaron/Downloads/specimen"

get '/ls/*' do
  path = params['splat'][0].gsub("/ls/", "")
  results = []
  Dir.entries("#{HOMEDIR}/#{path}").each do |f| 
    results << { :name => f, :isDir => File.directory?("#{HOMEDIR}/#{path}/#{f}") }
  end
  headers "Content-Type" => "application/json"
  return results.to_json
end

get '/touch/*' do
  path = params['splat'][0].gsub("/touch/", "")
  path = "#{HOMEDIR}/#{path}"
  FileUtils.touch(path)
  return path
end

get '/rm/*' do
  path = params['splat'][0].gsub("/rm/", "")
  if path != ""
    path = "#{HOMEDIR}/#{path}"
    if File.exist? path
      FileUtils.rm(path)
      return path
    else
      return 404
    end
  else
    return 403
  end
end

get '/mkdir/*' do
  path = params['splat'][0].gsub("/mkdir/", "")
  path = "#{HOMEDIR}/#{path}"
  FileUtils.mkdir(path)
  return path
end

get '/rmdir/*' do
  path = params['splat'][0].gsub("/rmdir/", "")
  if path != ""
    path = "#{HOMEDIR}/#{path}"
    if File.directory? path
      FileUtils.rm_rf(path)
      return path
    else 
      return 404
    end
  else
    return 403
  end
end

get '/read/*' do
  path = params['splat'][0].gsub("/mkdir/", "")
  path = "#{HOMEDIR}/#{path}"
  if File.exist? path
    return IO.read(path)
  else
    return 404
  end
end

post '/write/*' do
  path = params['splat'][0].gsub("/mkdir/", "")
  path = "#{HOMEDIR}/#{path}"
  if File.exist? path
    content = request.body.read
    IO.write(path, content)
    return 200
  else
    return 404
  end
end

post '/cp' do
  args = JSON.parse request.body.read
  source = args["source"]
  destination = args["destination"]
  src = "#{HOMEDIR}/#{source}"
  dest = "#{HOMEDIR}/#{destination}"
  if File.exist? src
    FileUtils.cp src, dest
    return 200
  else
    return 404
  end
end

post '/mv' do
  args = JSON.parse request.body.read
  source = args["source"]
  destination = args["destination"]
  src = "#{HOMEDIR}/#{source}"
  dest = "#{HOMEDIR}/#{destination}"
  if File.exist? src
    FileUtils.mv src, dest
    return 200
  else
    return 404
  end
end

post '/exec' do
  args = JSON.parse request.body.read
  cmd = args["cmd"]
  stream do |out|
    out << `#{cmd}`
  end
end