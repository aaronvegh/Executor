require 'sinatra'
require 'json'
require 'fileutils'
require 'cgi'
require 'digest'
require 'ptools'
require 'pathname'
require 'rest-client'

configure { set :port, 82 }
configure { set :bind, '0.0.0.0' }
HOMEDIR = "/home/codewerks/project"

before do
  if protected == false
    halt 403, {'Content-Type' => 'text/plain'}, 'Unauthorized'
  end
end

get '/ls/*' do
  path = params['splat'][0].gsub("/ls/", "")
  results = []
  fullPath = "#{HOMEDIR}/#{path}"
  if File.directory? fullPath
    Dir.entries("#{HOMEDIR}/#{path}").each do |f|
      if f != "."
        if f != ".."
          isDir = File.directory?("#{HOMEDIR}/#{path}/#{f}")
          if !isDir 
            isBinary = File.binary?("#{HOMEDIR}/#{path}/#{f}")
          else
            isBinary = false
          end
          mtime = isDir ? 0 : File.mtime("#{HOMEDIR}/#{path}/#{f}").to_i
          toHash = isDir ? "#{HOMEDIR}/#{path}/#{f}" : "#{HOMEDIR}/#{path}/#{f}/#{File.read("#{HOMEDIR}\/#{path}\/#{f}")}"
          hash = Digest::SHA256.hexdigest toHash
          resolved_path = path == "" ? nil : path
          results << { :name => f, :parentDir => resolved_path, :md5 => hash, :mtime => mtime, :isDir => isDir, :isBinary => isBinary }
        end
      end
    end
  else
    return 404
  end
  headers "Content-Type" => "application/json"
  return results.to_json
end

get '/isdirty' do
  path = Pathname.new("#{HOMEDIR}/../.is_dirty")
  if File.exist? path
    FileUtils.rm(path)
    return 200
  else
    return 204
  end
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
  path = params['splat'][0].gsub("/read/", "")
  path = "#{HOMEDIR}/#{path}"
  if File.exist? path
    return IO.read(path)
  else
    return 404
  end
end

get '/binaryread/*' do
  path = params['splat'][0].gsub("/binaryread", "")
  fullpath = "#{HOMEDIR}/#{path}"
  if File.exist? path
    send_file path, :filename => path, :type => 'Application/octet-stream'
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


def protected
  if authorized?
    return true
  else
    return false
  end
end

def bearer_token
  pattern = /^Bearer /
  header  = request.env["HTTP_AUTHORIZATION"] # <= env
  header.gsub(pattern, '') if header && header.match(pattern)
end

# check the token to make sure it is valid with our public key
def authorized?
  @token = bearer_token
  return false if @token == nil
  begin
    owner_token = `curl -s --unix-socket /dev/lxd/sock http://x/1.0/config/user.token`
    if owner_token != nil && !owner_token.empty?
      response = RestClient.get 'http://codewerks.app:81/users/valid', { :Authorization => "Bearer #{@token}" }
      return true if response.code == 200 && response.body == owner_token
    else
      return false
    end
  rescue RestClient::Forbidden
    return false
  end
end