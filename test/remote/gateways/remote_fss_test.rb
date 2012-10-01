require 'test_helper'

class RemoteFssTest < Test::Unit::TestCase
  def setup
    @gateway = FssGateway.new(fixtures(:fss))

    @amount = 100
    @credit_card = credit_card("4000100011112224")
    @declined_card = credit_card("4000300011112220")

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
    assert_equal "REPLACE WITH FAILED PURCHASE MESSAGE", response.message
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
