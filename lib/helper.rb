helpers do

	# Authentification
  def protected!(token_id)
    if env["session"] 
      flash[:notice] = "You don't have access to this section: " and \
      redirect back and \
      return unless authorized?(token_id)
    end
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?(token_id)
  end
 
  def authorized?(token_id)
    case request.env['REQUEST_METHOD']    
    when "DELETE", "PUT"
      ret = OpenTox::Authorization.authorize(request.env['SCRIPT_URI'], request.env['REQUEST_METHOD'], token_id)
      LOGGER.debug "OpenTox helpers OpenTox::Authorization authorized? method: #{request.env['REQUEST_METHOD']} , URI: #{request.env['SCRIPT_URI']}, token_id: #{token_id} with return #{ret}." 
      return ret
    when "POST"
      if OpenTox::Authorization.is_token_valid(token_id)
        LOGGER.debug "OpenTox helpers OpenTox::Authorization.is_token_valid: true"  
        return true
      end
      LOGGER.warn "OpenTox helpers POST on #{request.env['SCRIPT_URI']} with token_id: #{token_id} false."  
    end 
    LOGGER.debug "Not authorized for: 1. #{request['SCRIPT_URI']} 2. #{request.env['SCRIPT_URI']}  with Method: #{request.env['REQUEST_METHOD']} with Token #{token_id}"
    LOGGER.debug "Request infos: #{request.inspect}"
    return false
  end

  def unprotected_requests
    case  env['REQUEST_URI']
    when /\/login$|\/logout$|\/predict$|\/upload$/
      return true
    when /\/compound|\/feature|\/task|\/toxcreate/   #to fix: read from config | validation should be protected 
      return true
    else
      return false
    end
   end

  def check_token_id(token_id)
    return false if !token_id
    return true if token_id.size > 62
    false
  end  
end

before do

  unless unprotected_requests or env['REQUEST_METHOD'] == "GET"
    begin
      token_id = session[:token_id] if session[:token_id]
      token_id = params[:token_id]  if params[:token_id]  and !check_token_id(token_id)
      token_id = request.env['HTTP_TOKEN_ID'] if request.env['HTTP_TOKEN_ID'] and !check_token_id(token_id)
      # see http://rack.rubyforge.org/doc/SPEC.html
    rescue
      LOGGER.debug "OpenTox api wrapper: helper before filter: NO token_id." 
      token_id = ""
    end
    protected!(token_id) if AA_SERVER
  end
	    
end

