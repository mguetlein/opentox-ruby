helpers do

  # Authentification
  def protected!(subjectid)
    if env["session"]
      flash[:notice] = "You don't have access to this section: " and \
      redirect back and \
      return unless authorized?(subjectid)
    elsif !env["session"] && subjectid
      throw(:halt, [401, "Not authorized.\n"]) and \
      redirect back and \
      return unless authorized?(subjectid)
    end
    throw(:halt, [401, "Not authorized.\n"]) and \
    return unless authorized?(subjectid)
  end

  #Check Authorization for URI with method and subjectid. 
  def authorized?(subjectid)
    uri = clean_uri("#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}")
    if CONFIG[:authorization][:authorize_request].include?(request.env['REQUEST_METHOD'])
      ret = OpenTox::Authorization.authorize(uri, request.env['REQUEST_METHOD'], subjectid)
      LOGGER.debug "OpenTox helpers OpenTox::Authorization authorized? method: #{request.env['REQUEST_METHOD']} , URI: #{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}, subjectid: #{subjectid} with return >>#{ret}<<"
      return ret
    end
    if CONFIG[:authorization][:authenticate_request].include?(env['REQUEST_METHOD'])
      return true if OpenTox::Authorization.is_token_valid(subjectid)
    end
    LOGGER.debug "Not authorized for: #{request.env['rack.url_scheme']}://#{request['REQUEST_URI']} with Method: #{request.env['REQUEST_METHOD']} with Token #{subjectid}"
    return false
  end

  #cleans URI from querystring and file-extension. Sets port 80 to emptystring
  # @param [String] uri 
  def clean_uri(uri)
    out = URI.parse(uri)
    "#{out.scheme}:" + (out.port != 80 ? out.port : "") + "//#{out.host}#{out.path.chomp(File.extname(out.path))}"
  end

  def check_subjectid(subjectid)
    return false if !subjectid
    return true if subjectid.size > 62
    false
  end

  #unprotected uris for login/logout, webapplication ...
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

end

before do
  unless unprotected_requests or CONFIG[:authorization][:free_request].include?(env['REQUEST_METHOD']) 
    begin
      subjectid = session[:subjectid] if session[:subjectid]
      subjectid = params[:subjectid]  if params[:subjectid] and !check_subjectid(subjectid)
      subjectid = request.env['HTTP_SUBJECTID'] if request.env['HTTP_SUBJECTID'] and !check_subjectid(subjectid)
      # see http://rack.rubyforge.org/doc/SPEC.html
      subjectid = CGI.unescape(subjectid) if subjectid.include?("%23")
    rescue
      LOGGER.debug "OpenTox ruby api wrapper: helper before filter: NO subjectid for URI: #{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}"
      subjectid = ""
    end
    protected!(subjectid) if AA_SERVER
  end
end

