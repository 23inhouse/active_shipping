require 'active_shipping/shipping/carriers/bogus_carrier'
require 'active_shipping/shipping/carriers/ups'
require 'active_shipping/shipping/carriers/usps'
require 'active_shipping/shipping/carriers/fedex'
require 'active_shipping/shipping/carriers/shipwire'
require 'active_shipping/shipping/carriers/kunaki'
require 'active_shipping/shipping/carriers/canada_post'
require 'active_shipping/shipping/carriers/new_zealand_post'
require 'active_shipping/shipping/carriers/australia_post'
require 'active_shipping/shipping/carriers/fastway'

module ActiveMerchant
  module Shipping
    module Carriers
      class <<self
        def all
          [BogusCarrier, UPS, USPS, FedEx, Shipwire, Kunaki, CanadaPost, NewZealandPost, AustraliaPost, Fastway]
        end
      end
    end
  end
end