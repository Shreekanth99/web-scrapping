module Api
    module V1
      class CompaniesController < ApplicationController
        def index
          n = params[:n].to_i
          filters = params[:filters]
          scraper = YCombinatorScraper.new(n, filters)
          companies = scraper.scrape
  
          respond_to do |format|
            format.json { render json: companies }
            format.csv { send_data generate_csv(companies), filename: "companies-#{Date.today}.csv" }
          end
        end
  
        private
  
        def generate_csv(companies)
          CSV.generate(headers: true) do |csv|
            csv << ['Name', 'Location', 'Description', 'Batch']
  
            companies.each do |company|
              csv << [company[:name], company[:location], company[:description], company[:batch]]
            end
          end
        end
      end
    end
end
  