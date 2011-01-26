helpers do

  # Authentification
  def protected!(subjectid)
    if env["session"]
      unless authorized?(subjectid)
        flash[:notice] = "You don't have access to this section: "
        redirect back
      end
    elsif !env["session"] && subjectid
      unless authorized?(subjectid)
        raise OpenTox::NotAuthorizedError.new "Not authorized" 
      end
    else
      raise OpenTox::NotAuthorizedError.new "Not authorized" unless authorized?(subjectid)
    end
  end

  #Check Authorization for URI with method and subjectid. 
  def authorized?(subjectid)
    request_method = request.env['REQUEST_METHOD']
    uri = clean_uri("#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}")
    request_method = "GET" if request_method == "POST" &&  uri =~ /\/model\/\d+\/?$/
    return OpenTox::Authorization.authorized?(uri, request_method, subjectid)
  end

  #cleans URI from querystring and file-extension. Sets port 80 to emptystring
  # @param [String] uri 
  def clean_uri(uri)
    out = URI.parse(uri)
    out.path = out.path[0, out.path.rindex(/[0-9]/) + 1] if out.path.rindex(/[0-9]/) #cuts after id for a&a
    "#{out.scheme}:" + (out.port != 80 ? out.port : "") + "//#{out.host}#{out.path}"
  end

  #unprotected uris for login/logout, webapplication ...
  def unprotected_requests
    case  env['REQUEST_URI']
    when /\/login$|\/logout$|\/predict$|\/toxcreate\/models$/
      return true
    when /\/features/
      return false
    when /\/compound|\/feature|\/task|\/toxcreate/   #to fix: read from config | validation should be protected
      return true
    else
      return false
    end
   end

end

before do
  unless !AA_SERVER or unprotected_requests or CONFIG[:authorization][:free_request].include?(env['REQUEST_METHOD']) 
    begin
      subjectid = nil
      subjectid = session[:subjectid] if session[:subjectid]
      subjectid = params[:subjectid]  if params[:subjectid] and !subjectid
      subjectid = request.env['HTTP_SUBJECTID'] if request.env['HTTP_SUBJECTID'] and !subjectid
      # see http://rack.rubyforge.org/doc/SPEC.html
      subjectid = CGI.unescape(subjectid) if subjectid.include?("%23")
      @subjectid = subjectid
    rescue
      LOGGER.debug "OpenTox ruby api wrapper: helper before filter: NO subjectid for URI: #{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}"
      subjectid = ""
    end
    @subjectid = subjectid
    protected!(subjectid)
  end
end

