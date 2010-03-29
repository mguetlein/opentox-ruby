module OpenTox
	class Validation

		attr_accessor :uri

		def initialize(params)
			resource = RestClient::Resource.new(params[:uri], :user => @@users[:users].keys[0], :password => @@users[:users].values[0])
			@uri = resource.post(params).to_s
		end
		
		def self.crossvalidation(params)
			params[:uri] = File.join(@@config[:services]['opentox-validation'], "crossvalidation")
      params[:num_folds] = 10 unless params[:num_folds]
		 	params[:random_seed] = 2 unless params[:random_seed]
		 	params[:stratified] = false unless params[:stratified]
			OpenTox::Validation.new(params)
		end

	end
end
