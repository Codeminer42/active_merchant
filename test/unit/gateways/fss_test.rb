require 'test_helper'

class FssTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = FssGateway.new(
      :login => 'login',
      :password => 'password'
    )

    @credit_card = credit_card
    @amount = 100
  end

  def test_successful_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(successful_purchase_response)

    assert_success response

    assert_equal "849768440022761", response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response = stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.respond_with(failed_purchase_response)

    assert_failure response
    assert response.test?
  end

  def test_passing_cvv
    stub_comms do
      @gateway.purchase(@amount, @credit_card)
    end.check_request do |endpoint, data, headers|
      assert_match(/#{@credit_card.verification_value}/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_currency
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :currency => "USD")
    end.check_request do |endpoint, data, headers|
      assert_match(/USD/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_order_id
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :order_id => "932823723")
    end.check_request do |endpoint, data, headers|
      assert_match(/932823723/, data)
    end.respond_with(successful_purchase_response)
  end

  def test_passing_description
    stub_comms do
      @gateway.purchase(@amount, @credit_card, :description => "Awesome Services By Us")
    end.check_request do |endpoint, data, headers|
      assert_match(/Awesome Services By Us/, data)
    end.respond_with(successful_purchase_response)
  end

  private

  def successful_purchase_response
    %(
      <result>CAPTURED</result>
      <auth>999999</auth>
      <ref>227615274218</ref>
      <avr>N</avr>
      <postdate>1002</postdate>
      <tranid>849768440022761</tranid>
      <payid>-1</payid>
      <udf2></udf2>
      <udf5></udf5>
      <amt>1.00</amt>
    )
  end

  def failed_purchase_response
    %()
  end
end
