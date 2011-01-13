module OpenTox

  #Module for Authorization and Authentication
  #@example Authentication
  #  require "opentox-ruby-api-wrapper" 
  #  OpenTox::Authorization::AA_SERVER = "https://opensso.in-silico.ch" #if not set in .opentox/conf/[environment].yaml 
  #  token = OpenTox::Authorization.authenticate("benutzer", "passwort") 
  #@see http://www.opentox.org/dev/apis/api-1.2/AA OpenTox A&A API 1.2 specification
   
  module Authorization

    #Helper Class AA to create and send default policies out of xml templates
    #@example Creating a default policy to a URI 
    #  aa=OpenTox::Authorization::AA.new(tok)  
    #  xml=aa.get_xml('http://uri....')
    #  OpenTox::Authorization.create_policy(xml,tok)   
    
    class AA
      attr_accessor :user, :subjectid, :policy  
      
      #Generates AA object - requires subjectid
      # @param [String] subjectid  
      def initialize(subjectid)
        @user = Authorization.get_user(subjectid)
        @subjectid = subjectid
        @policy = Policies.new()
      end
      
      #Cleans AA Policies and loads default xml file into policy attribute
      #set uri and user, returns Policyfile(XML) for open-sso 
      # @param [String] URI to create a policy for
      def get_xml(uri)
        @policy.drop_policies
        @policy.load_default_policy(@user, uri)
        return @policy.to_xml
      end   
      
      #Loads and sends Policyfile(XML) to open-sso server
      # @param [String] URI to create a policy for      
      def send(uri)    
        xml = get_xml(uri)
        ret = false
        ret = Authorization.create_policy(xml, @subjectid) 
        LOGGER.debug "Policy send with subjectid: #{@subjectid}"
        LOGGER.warn "Not created Policy is: #{xml}" if !ret
        ret  
      end
      
    end
    
    #Returns the open-sso server set in the config file .opentox/config/[environment].yaml
    # @return [String, nil] the openSSO server URI or nil
    def self.server
      return AA_SERVER
    end

    #Authentication against OpenSSO. Returns token. Requires Username and Password.
    # @param [String, String]Username,Password 
    # @return [String, nil] gives subjectid or nil
    def self.authenticate(user, pw)
      return true if !AA_SERVER
      begin 
        resource = RestClient::Resource.new("#{AA_SERVER}/auth/authenticate")
        out = resource.post(:username=>user, :password => pw).sub("token.id=","").sub("\n","")
        return out
      rescue
        return nil
      end
    end
    
    #Logout on opensso. Make token invalid. Requires token
    # @param [String]subjectid the subjectid 
    # @return [Boolean] true if logout is OK
    def self.logout(subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/auth/logout")
        resource.post(:subjectid => subjectid)
        return true 
      rescue
        return false
      end
    end    
    
    #Authorization against OpenSSO for a URI with request-method (action) [GET/POST/PUT/DELETE]
    # @param [String,String,String]uri,action,subjectid
    # @return [Boolean, nil]  returns true, false or nil (if authorization-request fails).
    def self.authorize(uri, action, subjectid)
      return true if !AA_SERVER
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/auth/authorize")
        return true if resource.post(:uri => uri, :action => action, :subjectid => subjectid) == "boolean=true\n"
      rescue
        return nil
      end    
    end

    #Checks if a token is a valid token 
    # @param [String]subjectid subjectid from openSSO session 
    # @return [Boolean] subjectid is valid or not. 
    def self.is_token_valid(subjectid)
      return true if !AA_SERVER
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/auth/isTokenValid")
        return true if resource.post(:tokenid => subjectid) == "boolean=true\n"
      rescue
        return false
      end
    end
 
    #Returns array with all policies of the token owner
    # @param [String]subjectid requires subjectid
    # @return [Array, nil] returns an Array of policy names or nil if request fails
    def self.list_policies(subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/pol")
        out = resource.get(:subjectid => subjectid)
        return out.split("\n") 
      rescue
        return nil
      end
    end

    #Returns a policy in xml-format
    # @param [String, String]policy,subjectid 
    # @return [String] XML of the policy 
    def self.list_policy(policy, subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/pol")
        return resource.get(:subjectid => subjectid,:id => policy)
      rescue
        return nil
      end
    end
    
    #Returns the owner (who created the first policy) of an URI
    # @param [String, String]uri,subjectid
    # return [String, nil]owner,nil returns owner of the URI
    def self.get_uri_owner(uri, subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/pol")
        return resource.get(:uri => uri, :subjectid => subjectid).sub("\n","")
      rescue
        return nil
      end      
    end    
    
    #Checks if a policy exists to a URI. Requires URI and token.
    # @param [String, String]uri,subjectid
    # return [Boolean] 
    def self.uri_has_policy(uri, subjectid)
      owner = get_uri_owner(uri, subjectid)
      return true if owner and owner != "null"
      false
    end
    
    #List all policynames for a URI. Requires URI and token.
    # @param [String, String]uri,subjectid
    # return [Array, nil] returns an Array of policy names or nil if request fails   
    def self.list_uri_policies(uri, subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/pol")
        out = resource.get(:uri => uri, :polnames => true, :subjectid => subjectid)        
        policies = []; notfirstline = false
        out.split("\n").each do |line|
          policies << line if notfirstline
          notfirstline = true    
        end
        return policies 
      rescue
        return nil
      end      
    end    

    #Sends a policy in xml-format to opensso server. Requires policy-xml and token.
    # @param [String, String]policyxml,subjectid
    # return [Boolean] returns true if policy is created   
    def self.create_policy(policy, subjectid)
      begin
#        resource = RestClient::Resource.new("#{AA_SERVER}/Pol/opensso-pol")
        LOGGER.debug "OpenTox::Authorization.create_policy policy: #{policy[168,43]} with token:" + subjectid.to_s + " length: " + subjectid.length.to_s 
#        return true if resource.post(policy, :subjectid => subjectid, :content_type =>  "application/xml")
        return true if RestClientWrapper.post("#{AA_SERVER}/pol", {:subjectid => subjectid, :content_type =>  "application/xml"}, policy)        
      rescue
        return false
      end
    end
    
    #Deletes a policy
    # @param [String, String]policyname,subjectid
    # @return [Boolean,nil]
    def self.delete_policy(policy, subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/pol")
        LOGGER.debug "OpenTox::Authorization.delete_policy policy: #{policy} with token: #{subjectid}"
        return true if resource.delete(:subjectid => subjectid, :id => policy)        
      rescue
        return nil
      end
    end

    #Returns array of all possible LDAP-Groups
    # @param [String]subjectid
    # @return [Array]    
    def self.list_groups(subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/opensso/identity/search")
        grps = resource.post(:admin => subjectid, :attributes_names => "objecttype", :attributes_values_objecttype => "group")
        grps.split("\n").collect{|x|  x.sub("string=","")}
      rescue
        []
      end
    end    
    
    #Returns array of the LDAP-Groups of an user
    # @param [String]subjectid
    # @return [Array] gives array of LDAP groups of a user
    def self.list_user_groups(user, subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/opensso/identity/read")
        out = resource.post(:name => user, :admin => subjectid, :attributes_names => "group")
        grps = []
        out.split("\n").each do |line|
          grps << line.sub("identitydetails.group=","") if line.include?("identitydetails.group=")    
        end
        return grps
      rescue
        []
      end
    end    
    
    #Returns the owner (user id) of a token
    # @param [String]subjectid
    # @return [String]user 
    def self.get_user(subjectid)
      begin
        resource = RestClient::Resource.new("#{AA_SERVER}/opensso/identity/attributes")
        out = resource.post(:subjectid => subjectid, :attributes_names => "uid")
        user = ""; check = false
        out.split("\n").each do |line|
          if check
            user = line.sub("userdetails.attribute.value=","") if line.include?("userdetails.attribute.value=")
            check = false
          end
          check = true if line.include?("userdetails.attribute.name=uid") 
        end
        return user
      rescue
        nil
      end
    end
    
    #Send default policy with Authorization::AA class
    # @param [String, String]URI,subjectid
    def self.send_policy(uri, subjectid)
      return true if !AA_SERVER
      aa  = Authorization::AA.new(subjectid)
      ret = aa.send(uri)
      LOGGER.debug "OpenTox::Authorization send policy for URI: #{uri} | subjectid: #{subjectid} - policy created: #{ret}"
      ret
    end
    
    #Deletes all policies of an URI
    # @param [String, String]URI,subjectid
    # @return [Boolean]
    def self.delete_policies_from_uri(uri, subjectid)
      policies = list_uri_policies(uri, subjectid)
      policies.each do |policy|
        ret = delete_policy(policy, subjectid)
        LOGGER.debug "OpenTox::Authorization delete policy: #{policy} - with result: #{ret}"
      end    
      return true
    end

    #Checks (if subjectid is valid) if a policy exist and create default policy if not    
    def self.check_policy(uri, subjectid)
      token_valid = OpenTox::Authorization.is_token_valid(subjectid)      
      LOGGER.debug "OpenTox::Authorization.check_policy with uri: #{uri}, subjectid: #{subjectid} is valid: #{token_valid}"
      if uri and token_valid
        if !uri_has_policy(uri, subjectid)     
          return send_policy(uri, subjectid)
        else
          LOGGER.debug "OpenTox::Authorization.check_policy URI: #{uri} has already a Policy."
        end
      end
      true
    end    
    
  end 
end

