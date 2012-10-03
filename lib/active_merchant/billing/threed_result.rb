module ActiveMerchant
  module Billing
    class ThreedResult
      attr_reader :url, :pareq, :md

      def initialize(attrs)
        attrs ||= {}

        @enrolled = attrs[:enrolled]
        @url = attrs[:url]
        @pareq = attrs[:pareq]
        @md = attrs[:md]
      end

      def enrolled?
        @enrolled
      end
    end
  end
end
