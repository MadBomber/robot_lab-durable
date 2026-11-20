# frozen_string_literal: true

require 'htm'

module RobotLab
  module Durable
    class Adapter
      attr_reader :htm

      # @param robot_name [String] name HTM registers this robot under
      # @param node_source [#where, nil] model used to look up node metadata;
      #   defaults to HTM::Models::Node (resolved lazily, after HTM has connected)
      def initialize(robot_name:, node_source: nil)
        @htm         = HTM.new(robot_name: robot_name)
        @node_source = node_source
      end

      # Recall entries relevant to a query using HTM hybrid search.
      #
      # @param query [String] Natural-language search string
      # @param limit [Integer] Maximum number of results
      # @param strategy [Symbol] :vector, :fulltext, or :hybrid
      # @return [Array<Entry>]
      def recall(query:, limit: 20, strategy: :hybrid)
        nodes    = @htm.recall(query, limit: limit, strategy: strategy, raw: true)
        metadata = metadata_for(nodes.reject { |node| node['metadata'] }.map { |node| node['id'] })
        nodes.map { |node| Entry.from_node(with_metadata(node, metadata)) }
      end

      # Look up the metadata hashes of the given nodes in one query.
      #
      # HTM's raw recall rows carry id, content, created_at and ranking columns
      # but not the metadata column, so the reasoning and category written by
      # #record have to be fetched separately.
      #
      # @param node_ids [Array<Integer>]
      # @return [Hash{Integer => Hash}] node id => metadata (string keys)
      def metadata_for(node_ids)
        return {} if node_ids.empty?

        node_source.where(id: node_ids).select_map(%i[id metadata]).to_h { |id, meta| [id, meta.to_h] }
      end

      # @return [#where] the model queried by #metadata_for
      def node_source
        @node_source ||= HTM::Models::Node
      end

      # Return the node with its metadata filled in from the lookup, unless the
      # recall row already carries one.
      #
      # @param node [Hash] raw HTM recall row (string keys)
      # @param metadata [Hash{Integer => Hash}] result of #metadata_for
      # @return [Hash]
      def with_metadata(node, metadata)
        return node if node['metadata']

        node.merge('metadata' => metadata[node['id']])
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
