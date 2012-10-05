module ActiveMerchant
  module Billing
    class PreauthResult
      attr_reader :url, :fields

      def initialize(attrs)
        attrs ||= {}

        @enrolled = attrs[:enrolled]
        @url = attrs[:url]
        @fields = attrs[:fields]
      end

      def enrolled?
        @enrolled
      end
    end
  end
end
