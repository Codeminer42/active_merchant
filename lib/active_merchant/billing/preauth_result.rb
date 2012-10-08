module ActiveMerchant
  module Billing
    class PreauthResult
      attr_reader :url, :fields

      def initialize(attrs)
        attrs ||= {}

        @enrolled = attrs[:enrolled]
        @post = attrs[:post]
        @url = attrs[:url]
        @fields = attrs[:fields]
      end

      def enrolled?
        @enrolled
      end

      def post?
        @post
      end
    end
  end
end
