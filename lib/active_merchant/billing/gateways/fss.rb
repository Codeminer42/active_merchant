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

      def start_preauth(amount, payment_method, options={})
        post = {}
        add_invoice(post, amount, options)
        add_payment_method(post, payment_method)
        add_customer_data(post, options)

        commit("preauth", post)
      end

      def finish_preauth(raw_preauth)
        parsed_preauth = parse_preauth(raw_preauth)
        requires!(parsed_preauth, :pares, :md)

        {
          :pares => parsed_preauth[:pares],
          :paymentid => parsed_preauth[:md]
        }
      end

      def purchase(amount, payment_method, options={})
        post = {}
        if options[:preauth]
          add_preauth(post, options[:preauth])
          commit("use_preauth", post)
        else
          add_invoice(post, amount, options)
          add_payment_method(post, payment_method)
          add_customer_data(post, options)
          commit("purchase", post)
        end
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

      def add_preauth(post, preauth)
        post.merge!(preauth)
      end

      def parse(xml)
        response = {}

        doc = Nokogiri::XML.fragment(xml)
        doc.children.each do |node|
          if node.text?
            next
          elsif (node.elements.size == 0)
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
        "use_preauth" => nil,
      }

      def commit(action, post)
        post[:id] = @options[:login]
        post[:password] = @options[:password]
        post[:action] = ACTIONS[action] if ACTIONS[action]

        raw = parse(ssl_post(url(action), build_request(post)))

        succeeded = success_from(raw[:result])
        Response.new(
          succeeded,
          message_from(succeeded, raw),
          raw,
          :authorization => raw[:tranid],
          :test => test?,
          :preauth_result => {
            :enrolled => enrolled_from(action, raw),
            :url => raw[:url],
            :fields => {
              "PaReq" => raw[:pareq],
              "MD" => raw[:paymentid]
            }
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
        when "use_preauth"
          "MPIPayerAuthenticationXMLServlet"
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

      def parse_preauth(raw)
        case raw
        when Hash
          raw.inject({}){|hash, (k,v)| hash[k.to_s.downcase.to_sym] = v}
        when String
          raw.split("&").inject({}) do |hash, parameter|
            key, value = parameter.split("=")
            hash[CGI.unescape(key).downcase.to_sym] = CGI.unescape(value)
            hash
          end
        else
          raise ArgumentError.new("Unknown raw preauth format: #{raw}")
        end
      end

      def enrolled_from(action, raw)
        if action == "use_preauth"
          true
        else
          (raw[:result] == "ENROLLED")
        end
      end
    end
  end
end

