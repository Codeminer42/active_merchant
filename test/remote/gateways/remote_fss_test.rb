require 'test_helper'

class RemoteFssTest < Test::Unit::TestCase
  def setup
    @gateway = FssGateway.new(fixtures(:fss))

    @amount = 100
    @credit_card = credit_card("4012001037141112")

    # Use an American Express card to simulate a failure until we get a proper
    # test card.
    @declined_card = credit_card("377182068239368", :brand => :american_express)

    @options = {
      :order_id => "1",
      :billing_address => address,
      :description => "Store Purchase"
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
  end

  def test_failed_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "Invalid Brand.", response.message
    assert_equal "GW00160", response.params["error_code_tag"]
  end

  def test_invalid_login
    gateway = FssGateway.new(
                :login => "",
                :password => ""
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "Failed", response.message
  end
end
