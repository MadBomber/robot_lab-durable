# frozen_string_literal: true

require 'htm'

module RobotLab
  module Durable
    class Adapter
      attr_reader :htm

      def initialize(robot_name:)
        @htm = HTM.new(robot_name: robot_name)
      end

      # Recall entries relevant to a query using HTM hybrid search.
      #
      # @param query [String] Natural-language search string
      # @param limit [Integer] Maximum number of results
      # @param strategy [Symbol] :vector, :fulltext, or :hybrid
      # @return [Array<Entry>]
      def recall(query:, limit: 20, strategy: :hybrid)
        nodes = @htm.recall(query, limit: limit, strategy: strategy, raw: true)
        nodes.map { |node| Entry.from_node(node) }
      end

      # Store content in HTM long-term memory.
      #
      # @param content [String]
      # @param reasoning [String, nil] Why this is worth remembering
      # @param category [String, Symbol] fact, preference, pattern, correction, or observation
      # @return [Integer] HTM node_id
      def record(content:, reasoning: nil, category: 'fact')
        @htm.remember(
          content,
          metadata: {
            'reasoning' => reasoning,
            'category'  => category.to_s
          }
        )
      end
    end
  end
end
