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

  def test_successful_start_preauth_enrolled
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.start_preauth(@amount, @credit_card, @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil preauth_result = response.preauth_result
    assert preauth_result.enrolled?
    assert_match %r(^https://.+$), preauth_result.url
    assert_equal %w(PaReq MD), preauth_result.fields.keys
    assert_match %r(^.+$), preauth_result.fields["PaReq"]
    assert_match %r(^.+$), preauth_result.fields["MD"]
  end

  def test_successful_start_preauth_not_enrolled
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.start_preauth(@amount, credit_card("4012001038443335"), @options)
    assert_success response
    assert_equal "Succeeded", response.message
    assert_not_nil preauth_result = response.preauth_result
    assert !preauth_result.enrolled?
    assert_nil preauth_result.url
    assert_equal %w(PaReq MD), preauth_result.fields.keys
    assert_nil preauth_result.fields["PaReq"]
  end

  def test_failed_start_preauth
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.start_preauth(@amount, credit_card("4012001038488884"), @options)
    assert_failure response
    assert_equal "Authentication Not Available", response.message
  end

  include RemoteIntegrationHelper

  def test_successful_purchase_with_preauth
    gateway = FssGateway.new(fixtures(:fss_3d))

    assert response = gateway.start_preauth(@amount, @credit_card, @options)
    assert_success response

    preauth_page = submit %(
      <form action="#{response.preauth_result.url}" method="POST">
        <input type="hidden" name="PaReq" value="#{response.preauth_result.fields["PaReq"]}">
        <input type="hidden" name="MD" value="#{response.preauth_result.fields["MD"]}">
        <input type="hidden" name="TermUrl" value="http://example.com/post">
      </form>
    )

    form = preauth_page.forms.first
    assert_equal "http://example.com/post", form.action

    preauth = gateway.finish_preauth(form.request_data)

    purchase = gateway.purchase(@amount, @credit_card, @options.merge(preauth: preauth))
    assert_success purchase
    assert purchase.preauth_result.enrolled?
  end
end
