# class overwrites aka monkey patches

before {
  # hack: store sinatra in global var to make url_for and halt methods accessible
  $sinatra = self unless $sinatra
  # stupid internet explorer does not ask for text/html, add this manually 
  request.env['HTTP_ACCEPT'] += ";text/html" if request.env["HTTP_USER_AGENT"]=~/MSIE/
}

class Sinatra::Base
  # overwriting halt to log halts (!= 202)
  def halt(*response)
    LOGGER.error "halt "+response.first.to_s+" "+(response.size>1 ? response[1].to_s : "") if response and response.first and response.first >= 300
    # orig sinatra code:
    response = response.first if response.length == 1
    throw :halt, response
  end
end

