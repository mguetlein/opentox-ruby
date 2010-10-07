# class overwrites aka monkey patches

before {
  # hack: store sinatra in global var to make url_for and halt methods accessible
  $sinatra = self unless $sinatra
  # stupid internet explorer does not ask for text/html, add this manually 
  request.env['HTTP_ACCEPT'] += ";text/html" if request.env["HTTP_USER_AGENT"]=~/MSIE/
}

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
    # else, halt with 500 = internal error
    halt 500,request.env['sinatra.error']
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

