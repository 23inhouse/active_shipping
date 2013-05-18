module ActiveMerchant
  module Shipping
    class Fastway < Carrier

      cattr_reader :name
      @@name = "Fastway"

      URL = "http://api.fastway.org/v2/psc"

      def requirements
        [:key]
      end

      def find_franchise(postcode, options = {})
        options = @options.merge(options)
        request = FranchiseRequest.new(postcode, options)
        request.raw_responses = commit(request.urls, options) if request.australia_origin?
        request.franchise_response
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.merge(options)
        request = RateRequest.new(origin, destination, packages, options)
        request.raw_responses = commit(request.urls, options) if request.australia_origin?
        request.rate_response
      end

      def valid_credentials?
        true
      end

      protected

      def commit(urls, options)
        res = {}
        save_request(urls).map do |url|
          next res[url] if res[url]

          res[url] = begin
            ssl_get(url+"?api_key=#{options[:key]}")
          rescue => error
            error.response.body
          end
        end
      end

      def self.default_location
        Location.new({
          :country => "AU",
          :city => "Melbourne",
          :address1 => "321 Exhibition St",
          :state => 'VIC',
          :postal_code => "3000"
        })
      end

      class FastwayResponse < Response

        attr_reader :raw_responses, :franchises, :rates

        def initialize(success, message, params = {}, options = {})
          @raw_responses = options[:raw_responses]
          @franchises = options[:franchises]
          @rates = options[:rates]
          super
        end
      end

      class FastRequest
        attr_reader :urls
        attr_writer :raw_responses

        def franchise_response
          @franchises = franchises
          FastwayResponse.new(true, "success", response_params, franchise_response_options)
        rescue Exception => error
          FastwayResponse.new(false, error.message, response_params, franchise_response_options)
        end

        def rate_response
          @rates = rates
          FastwayResponse.new(true, "success", response_params, rate_response_options)
        rescue Exception => error
          FastwayResponse.new(false, error.message, response_params, rate_response_options)
        end

        def australia_origin?
          self.class.australia?(@origin)
        end

        protected

        def self.australia?(location)
          ['AU', nil , 'AUS'].include?(Location.from(location).country_code)
        end

        def franchises
          franchise_arrays.map do |franchise|
            franchise["franchise_code"]
          end
        end

        def franchise_arrays
          responses.map do |response|
            unless response["result"]
              raise(response["error"]["errorMessage"])
            end
            response["result"]
          end.compact
        end

        def rate_options(products)
          {
            :total_price => products.sum { |product| price(product) },
            :currency => "AUD",
            :service_code => products.first["type"]
          }
        end

        def rates
          rates_hash.map do |service, products|
            RateEstimate.new(@origin, @destination, Fastway.name, service, rate_options(products))
          end
        end

        def rates_hash
          products_hash.select { |service, products| products.size == @packages.size }
        end

        def products_hash
          @products_hash ||= product_arrays.group_by { |product| product["name"] }
        end

        def product_arrays
          @product_arrays ||= responses.map { |response|
            unless response["result"] && response["result"]["services"]
              raise(response["error"])
            end
            response["result"]["services"]
          }.compact.flatten
        end

        def franchise_response_options
          {
            :franchises => @franchises,
            :raw_responses => @raw_responses,
            :request => @urls,
            :test => @test
          }
        end

        def rate_response_options
          {
            :rates => @rates,
            :raw_responses => @raw_responses,
            :request => @urls,
            :test => @test
          }
        end

        def response_params
          { :responses => @responses }
        end

        def responses
          @responses = @raw_responses.map { |response| parse_response(response) }
        end

        def parse_response(response)
          JSON.parse(response)
        end
      end

      class FranchiseRequest < FastRequest
        def initialize(origin, options)
          @origin = Location.from(origin)
          @params = {}
          @test = options[:test]
          @franchises = @responses = @raw_responses = []
          @urls = [url]
        end

        def url
          "#{URL}/pickuprf/#{@origin.postal_code}/1"
        end
      end

      class RateRequest < FastRequest
        def initialize(origin, destination, packages, options)
          @origin = origin
          @destination = Location.from(destination)
          @packages = Array(packages).map { |package| FastwayPackage.new(package, api) }
          @params = {}
          @customer_type = options[:customer_type] == 'frequent' ? :frequent : :normal
          @test = options[:test]
          @rates = @responses = @raw_responses = []
          @urls = @packages.map { |package| url(package) }
        end

        def api
          'lookup'
        end

        def destination_params
          "#{@destination.city}/#{@destination.postal_code}"
        end

        def frequent?
          @customer_type == :frequent
        end

        def params(package)
          package.weight
        end

        def price(product)
          product[frequent? ? "totalprice_frequent" : "totalprice_normal"].to_f
        end

        def url(package)
          "#{URL}/lookup/#{@origin}/#{destination_params}/#{params(package)}"
        end
      end

      class FastwayPackage
        def initialize(package, api)
          @package = package
          @api = api
          @params = {
                      :weight => weight,
                      :length => length,
                      :width  => width,
                      :height => height
                    }
        end

        def params
          @params
        end

        def weight
          @package.kg
        end

        protected

        def length
          cm(:length)
        end

        def height
          cm(:height)
        end

        def width
          cm(:width)
        end

        def api_params
          send("#{@api}_params")
        end

        def international_params
          { :value => value }
        end

        def domestic_params
          {}
        end

        def cm(measurement)
          @package.cm(measurement)
        end

        def value
          return 0 unless @package.value && currency == "AUD"
          @package.value / 100
        end

        def currency
          @package.currency || "AUD"
        end
      end
    end
  end
end
