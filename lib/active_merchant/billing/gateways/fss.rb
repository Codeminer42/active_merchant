require "nokogiri"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FssGateway < Gateway
      # TODO:
      # * Implement 3D-secure flow
      # * Figure out how to pass billing address
      # * Fix capture/refund remote tests
      # * Use a proper declined card in remote tests
      self.display_name = "FSS"
      self.homepage_url = "http://www.fss.co.in/"

      self.test_url = "https://securepgtest.fssnet.co.in/pgway/servlet/"
      self.live_url = "https://securepg.fssnet.co.in/pgway/servlet/"

      self.supported_countries = ["IN"]
      self.default_currency = "INR"
      self.money_format = :dollars
      self.supported_cardtypes = [:visa, :master, :discover, :diners_club]

      def initialize(options={})
        requires!(options, :login, :password)
        @options = options
        super
      end

      def preauthorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("preauth", post)
      end

      def purchase(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("purchase", post)
      end

      def authorize(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("authorize", post)
      end

      def capture(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("capture", post)
      end

      def refund(amount, authorization, options={})
        post = {}
        add_invoice(post, amount, options)
        add_reference(post, authorization)
        add_customer_data(post, options)

        commit("refund", post)
      end

      private

      CURRENCY_CODES = Hash.new{|h,k| raise ArgumentError.new("Unsupported currency for FSS: #{k}")}
      CURRENCY_CODES["INR"] = "356"

      def add_invoice(post, amount, options)
        post[:amt] = amount(amount)
        post[:currencycode] = CURRENCY_CODES[options[:currency] || currency(amount)]
        post[:trackid] = options[:order_id] if options[:order_id]
        post[:udf1] = options[:description] if options[:description]
      end

      def add_customer_data(post, options)
        post[:udf2] = options[:email] if options[:email]
      end

      def add_payment_method(post, payment_method)
        post[:member] = payment_method.name
        post[:card] = payment_method.number
        post[:cvv2] = payment_method.verification_value
        post[:expyear] = format(payment_method.year, :four_digits)
        post[:expmonth] = format(payment_method.month, :two_digits)
      end

      def add_reference(post, authorization)
        post[:tranid] = authorization
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
        "preauth" => "1",
        "refund" => "2",
        "authorize" => "4",
        "capture" => "5",
      }

      def commit(action, post)
        post[:id] = @options[:login]
        post[:password] = @options[:password]
        post[:action] = ACTIONS[action]

        raw = parse(ssl_post(url(action), build_request(post)))
        p raw

        succeeded = success_from(raw[:result])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => raw[:tranid],
          :test => test?,
          :threed_result => {
            :enrolled => (raw[:result] == "ENROLLED"),
            :url => raw[:url],
            :pareq => raw[:pareq],
            :md => raw[:payment_id]
          }
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

      def url(action)
        endpoint = case action
        when "preauth"
          "MPIVerifyEnrollmentXMLServlet"
        else
          "TranPortalXMLServlet"
        end
        (test? ? test_url : live_url) + endpoint
      end

      def success_from(result)
        case result
        when "CAPTURED", "APPROVED", "NOT ENROLLED", "ENROLLED"
          true
        else
          false
        end
      end

      def message_from(succeeded, response)
        if succeeded
          "Succeeded"
        else
          (response[:error_text] || response[:result]).split("-").last
        end
      end
    end
  end
end

