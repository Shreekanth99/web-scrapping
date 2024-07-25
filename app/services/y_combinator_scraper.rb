require 'nokogiri'
require 'httparty'
require 'concurrent'

class YCombinatorScraper
  BASE_URL = 'https://www.ycombinator.com/companies'

  def initialize(n, filters)
    @n = n
    @filters = filters
  end

  def scrape
    companies = Concurrent::Array.new
    page_number = 1
    thread_pool = Concurrent::FixedThreadPool.new(10) # Adjust thread count based on your needs

    while companies.size < @n
      thread_pool.post do
        begin
          response = HTTParty.get("#{BASE_URL}?page=#{page_number}")
          if response.code == 200
            doc = Nokogiri::HTML(response.body)
            companies_on_page = parse_companies(doc)
            companies.concat(companies_on_page)
          else
            puts "Failed to fetch page #{page_number}: #{response.message}"
          end
        rescue => e                                                                                                                                                                                                                                                                                                                                                                                                                                                     
          puts "Error fetching page #{page_number}: #{e.message}"
        end
      end
      page_number += 1
    end

    thread_pool.shutdown
    thread_pool.wait_for_termination

    filtered_companies = apply_filters(companies)
    filtered_companies.take(@n)
  end

  private

  def parse_companies(doc)
    companies = []
    # Locate the section containing the list of companies
    section = doc.css('div._section_86jzd_146._results_86jzd_326')
    return companies unless section # Return empty array if section not found

    # Loop through the children array to extract company information
    section.each do |child|
      next unless child.name == 'a' && child[:class].include?('_company_86jzd_338')
      
      company = {
        name: child.at_css('._coName_86jzd_453')&.text&.strip,
        location: child.at_css('._coLocation_86jzd_469')&.text&.strip,
        description: child.at_css('._coDescription_86jzd_478')&.text&.strip,
        batch: child.at_css('a[href*="batch"] span.pill')&.text&.strip,
        industry: child.css('a[href*="industry"] span.pill')&.map(&:text)&.join(', '),
        tags: child.css('._pillWrapper_86jzd_33 .pill')&.map(&:text)&.map(&:strip)
      }
      companies << company
    end
    companies
  end
  def apply_filters(companies)
    filtered = companies

    if @filters[:batch]
      filtered = filtered.select { |c| c[:batch] == @filters[:batch] }
    end

    if @filters[:industry]
      filtered = filtered.select { |c| c[:industry] == @filters[:industry] }
    end

    if @filters[:region]
      filtered = filtered.select { |c| c[:location].include?(@filters[:region]) }
    end

    if @filters[:tag] == "Top Companies"
      filtered = filtered.select { |c| c[:tags].include?("Top Companies") }
    end

    if @filters[:company_size]
      min_size, max_size = @filters[:company_size].split('-').map(&:to_i)
      filtered = filtered.select { |c| c[:employees].between?(min_size, max_size) }
    end

    if @filters[:is_hiring]
      filtered = filtered.select { |c| c[:is_hiring] }
    end

    if @filters[:nonprofit] == false
      filtered = filtered.reject { |c| c[:tags].include?("Nonprofit") }
    end

    if @filters[:black_founded]
      filtered = filtered.select { |c| c[:tags].include?("Black-founded") }
    end

    if @filters[:hispanic_latino_founded]
      filtered = filtered.select { |c| c[:tags].include?("Hispanic & Latino-founded") }
    end

    if @filters[:women_founded]
      filtered = filtered.select { |c| c[:tags].include?("Women-founded") }
    end

    filtered
  end
end
