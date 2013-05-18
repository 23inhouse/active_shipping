require 'test_helper'

class FastwayTest < Test::Unit::TestCase

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = Fastway.new(fixtures(:fastway))
    @melbourne = @locations[:melbourne]
    @sydney = @locations[:sydney]
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_franchise_response
    response = @carrier.find_franchise(@melbourne)

    assert response.is_a?(Response)
    assert response.success?
    assert response.franchises.any?
    assert response.franchises.first.is_a?(String)
    assert_equal 'MEL', response.franchises.first
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
    assert_equal 1, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_rate_response
    response = @carrier.find_rates('MEL', @sydney, @packages[:case_of_wine])

    assert response.is_a?(Response)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
    assert_equal 1, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_combined_rate_response
    response = @carrier.find_rates('MEL', @sydney, @packages.values_at(:book, :american_wii))
    assert response.is_a?(Response)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
    assert_equal 2, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_mulitple_packages_rate_response
    response = @carrier.find_rates('MEL', @sydney, [@packages[:case_of_wine], @packages[:case_of_wine]])

    assert response.is_a?(Response)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
    assert_equal 2, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_failed_rate_response_raises
    assert_raises ActiveMerchant::Shipping::ResponseError do
      @carrier.find_rates('MEL', @sydney, @packages[:shipping_container])
    end
  end

  def test_failed_rate_response_message
    error = @carrier.find_rates('MEL', @sydney, @packages[:shipping_container]) rescue $!
    assert_match /WeightInKg must be less than 25kg!. The actual value is 2200./, error.message
  end
end
