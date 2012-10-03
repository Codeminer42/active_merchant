require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FssGateway < Gateway
      # TODO:
      # * Fix remote tests by figuring out how to trigger failure
      # * Figure out how to pass billing address
      # * Implement authorize/capture/refund
      # * Figure out if discover/amex will work
      # * Implement 3D-secure flow
      self.display_name = "FSS"
      self.homepage_url = "http://www.fss.co.in/"

      self.test_url = "https://securepgtest.fssnet.co.in/pgway/servlet/"
      self.live_url = "https://securepg.fssnet.co.in/pgway/servlet/"

      self.supported_countries = ["IN"]
      self.default_currency = "INR"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master]

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def purchase(amount, payment_method, options = {})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("purchase", post)
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Invalid currency for FSS: #{k}")}
      CURRENCY_CODES["INR"] = "356"

      def add_invoice(post, amount, options)
        post[:amt] = amount(amount)
        post[:currencycode] = CURRENCY_CODES[options[:currency] || currency(amount)]
        post[:trackid] = options[:order_id]
        post[:udf1] = options[:description]
      end

      def add_customer_data(post, options)
        post[:udf2] = options[:email]
      end

      def add_payment_method(post, payment_method)
        post[:member] = payment_method.name
        post[:card] = payment_method.number
        post[:cvv2] = payment_method.verification_value
        post[:expyear] = format(payment_method.year, :four_digits)
        post[:expmonth] = format(payment_method.month, :two_digits)
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML.fragment(xml)
        doc.children.each do |node|
          if (node.elements.size == 0)
            response[node.name.downcase.to_sym] = node.text
          else
            node.elements.each do |childnode|
              name = "#{node.name.downcase}_#{childnode.name.downcase}"
              response[name.to_sym] = childnode.text
            end
          end
        end

        response
      end

      ACTIONS = {
        "purchase" => "1",
        "authorization" => "4",
      }

      def commit(action, post)
        post[:id] = @options[:login]
        post[:password] = @options[:password]
        post[:action] = ACTIONS[action]

        raw = parse(ssl_post(url(action), build_request(post)))

        succeeded = (raw[:result] == "CAPTURED")
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => raw[:tranid],
          :test => test?
        )
      end

      def build_request(post)
        xml = Builder::XmlMarkup.new :indent => 2
        xml.instruct!
        post.each do |field, value|
          xml.tag!(field, value)
        end
        xml.target!
      end

      URLS = {
        "purchase" => "TranPortalXMLServlet"
      }

      def url(action)
        (test? ? test_url : live_url) + URLS[action]
      end

      def message_from(succeeded, response)
        (succeeded ? "Succeeded" : "Failed")
      end
    end
  end
end

