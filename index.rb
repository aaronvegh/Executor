require 'sinatra'
require 'json'
require 'fileutils'
require 'cgi'
require 'digest'

configure { set :server, :thin }
configure { set :bind, '0.0.0.0' }
HOMEDIR = File.expand_path(File.dirname(__FILE__)).gsub!("Executor", "projects")

get '/ls/*' do
  path = params['splat'][0].gsub("/ls/", "")
  results = []
  fullPath = "#{HOMEDIR}/#{path}"
  if File.directory? fullPath
    Dir.entries("#{HOMEDIR}/#{path}").each do |f|
      if f != "."
        if f != ".."
          isDir = File.directory?("#{HOMEDIR}/#{path}/#{f}")
          mtime = isDir ? 0 : File.mtime("#{HOMEDIR}/#{path}/#{f}").to_i
          toHash = isDir ? "#{HOMEDIR}/#{path}/#{f}" : "#{f}#{File.read("#{HOMEDIR}\/#{path}\/#{f}")}"
          hash = Digest::SHA256.hexdigest toHash
          resolved_path = path == "" ? nil : path
          results << { :name => f, :parentDir => resolved_path, :md5 => hash, :mtime => mtime, :isDir => isDir }
        end
      end
    end
  else
    return 404
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
  path = params['splat'][0].gsub("/write/", "")
  path = "#{HOMEDIR}/#{path}"
  content = request.body.read
  IO.write(path, content)
  return 200
end

post '/upload/*' do
  path = params['splat'][0].gsub("/upload/", "")
  path = "#{HOMEDIR}/#{path}"
  File.open(path, 'wb') do |f|
      f.write(request.body.read)
      return 200
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
  source = CGI::unescape(args["source"])
  destination = CGI::unescape(args["destination"])
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
