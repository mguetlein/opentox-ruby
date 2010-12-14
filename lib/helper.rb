helpers do

  # Authentification
  def protected!(token_id)
    if env["session"]
      flash[:notice] = "You don't have access to this section: " and \
      redirect back and \
      return unless authorized?(token_id)
    elsif !env["session"] && token_id
      throw(:halt, [401, "Not authorized.\n"]) and \
      redirect back and \
      return unless authorized?(token_id)
    end
    throw(:halt, [401, "Not authorized.\n"]) and \
    return unless authorized?(token_id)
  end

  def authorized?(token_id)
    if CONFIG[:authorization][:authorize_request].include?(request.env['REQUEST_METHOD'])
      ret = OpenTox::Authorization.authorize("#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}", request.env['REQUEST_METHOD'], token_id)
      LOGGER.debug "OpenTox helpers OpenTox::Authorization authorized? method: #{request.env['REQUEST_METHOD']} , URI: #{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}, token_id: #{token_id} with return #{ret}."
      return ret
    end
    if CONFIG[:authorization][:authenticate_request].include?(env['REQUEST_METHOD'])
      if OpenTox::Authorization.is_token_valid(token_id)
        return true
      end
    end
    LOGGER.debug "Not authorized for: #{request.env['rack.url_scheme']}://#{request['REQUEST_URI']} with Method: #{request.env['REQUEST_METHOD']} with Token #{token_id}"
    return false
  end

  def unprotected_requests
    case  env['REQUEST_URI']
    when /\/login$|\/logout$|\/predict$|\/toxcreate\/models$/
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
  unless unprotected_requests or CONFIG[:authorization][:free_request].include?(env['REQUEST_METHOD']) 
    begin
      token_id = session[:token_id] if session[:token_id]
      token_id = params[:token_id]  if params[:token_id]  and !check_token_id(token_id)
      token_id = request.env['HTTP_TOKEN_ID'] if request.env['HTTP_TOKEN_ID'] and !check_token_id(token_id)
      # see http://rack.rubyforge.org/doc/SPEC.html
      token_id = CGI.unescape(token_id) if token_id.include?("%23")
    rescue
      LOGGER.debug "OpenTox ruby api wrapper: helper before filter: NO token_id."
      token_id = ""
    end
    protected!(token_id) if AA_SERVER
  end
end

