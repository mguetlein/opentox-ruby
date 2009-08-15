helpers do

	# Authentification
  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth") and \
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['api', API_KEY]
  end

	    
=begin
	def xml(object)
		builder do |xml| 
			xml.instruct!
			object.to_xml
		end
	end
=end

end

