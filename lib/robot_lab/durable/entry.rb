# frozen_string_literal: true

module RobotLab
  module Durable
    Entry = Data.define(:node_id, :content, :reasoning, :category, :created_at) do
      def self.from_node(node)
        meta = node['metadata'] || {}
        new(
          node_id:    node['id'],
          content:    node['content'],
          reasoning:  meta['reasoning'],
          category:   (meta['category'] || 'fact').to_sym,
          created_at: node['created_at']
        )
      end
    end
  end
end
