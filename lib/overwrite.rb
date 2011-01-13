# class overwrites aka monkey patches
# hack: store sinatra in global var to make url_for and halt methods accessible
before{ $sinatra = self unless $sinatra }

# handle errors manually
# this is to return 502, when an error occurs during a rest-call (see rest_client_wrapper.rb)
set :raise_errors, Proc.new { false }
set :show_exceptions, false
error do
  # try if the error is an OpenTox::Error 
  if OpenTox::Error.parse(request.env['sinatra.error'].to_s)
    # if true, this error comes from rest_client_wrapper, halt with 502
    # (502 is defined in OT API as Error coming from other service)
    halt 502,request.env['sinatra.error']
  else
    # else, raise exception, this will return 500 = internal error
    raise request.env['sinatra.error']
  end
end

class Sinatra::Base
  # overwriting halt to log halts (!= 202)
  def halt(*response)
    LOGGER.error "halt "+response.first.to_s+" "+(response.size>1 ? response[1].to_s : "") if response and response.first and response.first >= 300
    # orig sinatra code:
    response = response.first if response.length == 1
    throw :halt, response
  end
end

class String
  def task_uri?
    self.uri? && !self.match(/task/).nil?
  end
  
  def dataset_uri?
   self.uri? && !self.match(/dataset/).nil?
  end
 
  def self.model_uri?
   self.uri? && !self.match(/model/).nil?
  end

  def uri?
    begin
      u = URI::parse(self)
      return (u.scheme!=nil and u.host!=nil)
    rescue URI::InvalidURIError
      return false
    end
  end

  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

require 'logger'
# logging
#class Logger
class OTLogger < Logger
  
  def pwd
    path = Dir.pwd.to_s
    index = path.rindex(/\//)
    return path if index==nil
    path[(index+1)..-1]
  end
  
  def trace()
    lines = caller(0)
    n = 2
    line = lines[n]
    
    while (line =~ /spork.rb/ or line =~ /create/ or line =~ /overwrite.rb/)
      n += 1
      line = lines[n]
    end
  
    index = line.rindex(/\/.*\.rb/)
    return line if index==nil
    line[index..-1]
  end
  
  def format(msg)
    pwd.ljust(18)+" :: "+msg.to_s+"           :: "+trace+" :: "+($sinatra ? $sinatra.request.env['REMOTE_ADDR'] : nil).to_s
  end
  
  def debug(msg)
    super format(msg)
  end
  
  def info(msg)
    super format(msg)
  end
  
  def warn(msg)
    super format(msg)
  end

  def error(msg)
    super format(msg)
  end

end

