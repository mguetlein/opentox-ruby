helpers do
 
  def protected!
    response['WWW-Authenticate'] = %(Basic realm="Testing HTTP Auth") and \
    throw(:halt, [401, "Not authorized\n"]) and \
    return unless authorized?
  end
 
  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && valid_user?
  end
  
  def valid_user?
    users = @@users[:users]
    return @auth.credentials == [@auth.username, users.fetch(@auth.username)] if users.has_key?(@auth.username)
    return false
  end
 
end
 
before do
  protected! unless env['REQUEST_METHOD'] == "GET"
end