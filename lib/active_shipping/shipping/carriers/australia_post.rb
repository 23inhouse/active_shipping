module ActiveMerchant
  module Shipping
    class AustraliaPost < Carrier

      cattr_reader :name
      @@name = "Australia Post"

      URL = "http://auspost.com.au/api/postage"

      def requirements
        [:key]
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.merge(options)
        request = RateRequest.from(origin, destination, packages, options)
        request.raw_responses = commit(request.urls, options) if request.australia_origin?
        request.rate_response
      end

      protected

      def commit(urls, options)
        res = {}
        save_request(urls).map do |url|
          next res[url] if res[url]

          res[url] = begin
            ssl_get(url, {'AUTH-KEY' => options[:key]})
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

      class AustraliaPostRateResponse < RateResponse

        attr_reader :raw_responses

        def initialize(success, message, params = {}, options = {})
          @raw_responses = options[:raw_responses]
          super
        end
      end

      class RateRequest
        attr_reader :urls
        attr_writer :raw_responses

        def self.from(*args)
          return International.new(*args) unless domestic?(args[0..1])
          Domestic.new(*args)
        end

        def initialize(origin, destination, packages, options)
          @origin = Location.from(origin)
          @destination = Location.from(destination)
          @packages = Array(packages).map { |package| AustraliaPostPackage.new(package, api) }
          @params = {}
          @test = options[:test]
          @rates = @responses = @raw_responses = []
          @urls = @packages.map { |package| url(package) }
        end

        def rate_response
          @rates = rates
          AustraliaPostRateResponse.new(true, "success", response_params, response_options)
        rescue Exception => error
          AustraliaPostRateResponse.new(false, error.message, response_params, response_options)
        end

        def australia_origin?
          self.class.australia?(@origin)
        end

        protected

        def self.australia?(location)
          ['AU', nil , 'AUS'].include?(Location.from(location).country_code)
        end

        def self.domestic?(locations)
          locations.select { |location| australia?(location) }.size == 2
        end

        def response_options
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

        def rate_options(products)
          {
            :total_price => products.sum { |product| price(product) },
            :currency => "AUD",
            :service_code => products.first["code"]
          }
        end

        def rates
          rates_hash.map do |service, products|
            RateEstimate.new(@origin, @destination, AustraliaPost.name, service, rate_options(products))
          end
        end

        def rates_hash
          products_hash.select { |service, products| products.size == @packages.size }
        end

        def products_hash
          product_arrays.group_by { |product| product["name"] }
        end

        def product_arrays
          responses.map { |response|
            unless response["services"] && response["services"]["service"]
              raise(response["error"]["errorMessage"])
            end
            response["services"]["service"]
          }.compact.flatten
        end

        def responses
          @responses = @raw_responses.map { |response| parse_response(response) }
        end

        def parse_response(response)
          JSON.parse(response)
        end

        def url(package)
          "#{URL}/#{api}.json?#{params(package).to_query}"
        end

        def params(package)
          @params.merge(api_params).merge(package.params)
        end
      end

      class Domestic < RateRequest
        def api
          'parcel/domestic/service'
        end

        def api_params
          {
            :from_postcode => @origin.postal_code,
            :to_postcode => @destination.postal_code,
          }
        end

        def price(product)
          product["price"].to_f
        end
      end

      class International < RateRequest

        def rates
          raise "Australia Post packages must originate in Australia" unless australia_origin?
          super
        end

        def api
          'parcel/international/service'
        end

        def api_params
          { :country_code => @destination.country_code }
        end

        def price(product)
          product["price"].to_f
        end
      end

      class AustraliaPostPackage
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

        protected

        def weight
          @package.kg
        end

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
