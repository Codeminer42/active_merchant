require 'test_helper'
require 'remote/integrations/remote_integration_helper'

class RemoteFssTest < Test::Unit::TestCase
  def setup
    @gateway = FssGateway.new(fixtures(:fss))

    @amount = 100
    @credit_card = credit_card("4012001037141112")

    # Use an American Express card to simulate a failure until we get a proper
    # test card.
    @declined_card = credit_card("377182068239368", :brand => :american_express)

    @options = {
      :order_id => generate_unique_id,
      :billing_address => address,
      :description => "Store Purchase"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    p response
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
  end

  def test_successful_authorize_and_capture
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_match %r(^\d+$), response.authorization

    assert capture = @gateway.capture(@amount, response.authorization)
    assert_success capture
    assert_equal "Succeeded", capture.message
  end

  def test_failed_authorize
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
  end

  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert refund = @gateway.refund(@amount, response.authorization)
    assert_success refund
    assert_equal "Succeeded", capture.message
  end

  def test_invalid_login
    gateway = FssGateway.new(
                :login => "",
                :password => ""
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "TranPortal ID required.", response.message
  end

  include RemoteIntegrationHelper

  def test_3d_successful_preauthorize_enrolled
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.preauthorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil threed_result = response.threed_result
    assert threed_result.enrolled?
    assert_match %r(^https://.+$), threed_result.url
    assert_match %r(^.+$), threed_result.pareq
  end

  def test_3d_successful_preauthorize_not_enrolled
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.preauthorize(@amount, credit_card("4012001038443335"), @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil threed_result = response.threed_result
    assert !threed_result.enrolled?
    assert_nil threed_result.url
    assert_nil threed_result.pareq
  end

  def test_3d_failed_preauthorize
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.preauthorize(@amount, credit_card("4012001038488884"), @options)
    assert_failure response
    assert_equal "Authentication Not Available", response.message
  end
end
