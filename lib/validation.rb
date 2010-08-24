module OpenTox
	class Validation

		attr_accessor :uri

		def initialize(params)
      @uri = OpenTox::RestClientWrapper.post(File.join(@@config[:services]["opentox-validation"],"/crossvalidation"),params,nil,false)
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

