# class overwrites aka monkey patches
# hack: store sinatra in global var to make url_for and halt methods accessible
before{ $sinatra = self unless $sinatra }

class Sinatra::Base
  # overwriting halt to log halts (!= 202)
  def halt(*response)
    LOGGER.error "halt "+response.first.to_s+" "+(response.size>1 ? response[1].to_s : "") if response and response.first and response.first >= 300
    # orig sinatra code:
    response = response.first if response.length == 1
    throw :halt, response
  end
end

