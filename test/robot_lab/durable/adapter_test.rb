# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module Durable
    # Stand-in for HTM — records calls without hitting PostgreSQL.
    #
    # #recall returns rows shaped like HTM 0.0.32's real raw rows (see
    # HTM::LongTermMemory hybrid/vector/fulltext search): string keys, an
    # Integer id, a Time created_at, ranking columns — and NO 'metadata' key.
    class FakeHTM
      # Build a row the way HTM's hybrid search returns it.
      def self.raw_row(id:, content:, created_at: Time.utc(2026, 1, 1))
        {
          'id'            => id,
          'content'       => content,
          'access_count'  => 0,
          'created_at'    => created_at,
          'token_count'   => 4,
          'rrf_score'     => 0.016,
          'fulltext_rank' => 1,
          'text_rank'     => 0.5
        }
      end

      attr_reader :remembered, :last_recall_args

      def initialize(robot_name:)
        @robot_name      = robot_name
        @remembered      = []
        @last_recall_args = nil
        @nodes           = []
      end

      def remember(content, metadata: {})
        @remembered << { content: content, metadata: metadata }
        @remembered.size
      end

      def recall(query, limit: 20, strategy: :hybrid, raw: false, **)
        @last_recall_args = { query: query, limit: limit, strategy: strategy, raw: raw }
        @nodes
      end

      def stub_nodes(nodes)
        @nodes = nodes
      end
    end

    # Stand-in for HTM::Models::Node — answers the one Sequel chain the adapter
    # uses, `where(id: ids).select_map(%i[id metadata])`, returning [id, metadata]
    # pairs for the ids it knows (unknown ids are simply absent, as in SQL).
    class FakeNodeSource
      attr_reader :queries

      def initialize(metadata_by_id = {})
        @metadata_by_id = metadata_by_id
        @queries        = []
      end

      def where(id:)
        @queries << id
        Selection.new(@metadata_by_id.slice(*id))
      end

      Selection = Struct.new(:rows) do
        def select_map(columns)
          raise ArgumentError, "unexpected columns #{columns.inspect}" unless columns == %i[id metadata]

          rows.to_a
        end
      end
    end

    class AdapterTest < Minitest::Test
      def setup
        @fake_htm = FakeHTM.new(robot_name: 'tester')
        @adapter  = build_adapter
      end

      def build_adapter(metadata_by_id = {})
        @node_source = FakeNodeSource.new(metadata_by_id)
        adapter = Adapter.allocate
        adapter.instance_variable_set(:@htm, @fake_htm)
        adapter.instance_variable_set(:@node_source, @node_source)
        adapter
      end

      def test_record_calls_htm_remember_with_content
        @adapter.record(content: 'Prefer keyword args', reasoning: 'Clearer', category: 'preference')
        assert_equal 1, @fake_htm.remembered.size
        assert_equal 'Prefer keyword args', @fake_htm.remembered.first[:content]
      end

      def test_record_passes_reasoning_and_category_in_metadata
        @adapter.record(content: 'fact', reasoning: 'because', category: 'fact')
        meta = @fake_htm.remembered.first[:metadata]
        assert_equal 'because', meta['reasoning']
        assert_equal 'fact',    meta['category']
      end

      def test_record_coerces_category_to_string
        @adapter.record(content: 'c', category: :pattern)
        meta = @fake_htm.remembered.first[:metadata]
        assert_equal 'pattern', meta['category']
      end

      def test_record_accepts_nil_reasoning
        @adapter.record(content: 'c', reasoning: nil, category: 'fact')
        meta = @fake_htm.remembered.first[:metadata]
        assert_nil meta['reasoning']
      end

      def test_recall_returns_entries_built_from_nodes
        @fake_htm.stub_nodes([FakeHTM.raw_row(id: 1, content: 'Use frozen strings')])
        entries = @adapter.recall(query: 'frozen')
        assert_equal 1, entries.size
        assert_kind_of Entry, entries.first
        assert_equal 1, entries.first.node_id
        assert_equal 'Use frozen strings', entries.first.content
        assert_equal Time.utc(2026, 1, 1), entries.first.created_at
      end

      # Regression: HTM raw recall rows have no 'metadata', so reasoning and
      # category used to come back as nil / :fact for every recalled entry.
      def test_recall_restores_reasoning_and_category_from_node_metadata
        adapter = build_adapter(
          1 => { 'reasoning' => 'Speed', 'category' => 'pattern' },
          2 => { 'reasoning' => nil, 'category' => 'observation' }
        )
        @fake_htm.stub_nodes([
                               FakeHTM.raw_row(id: 1, content: 'Use frozen strings'),
                               FakeHTM.raw_row(id: 2, content: 'Tests run under rake')
                             ])
        first, second = adapter.recall(query: 'ruby')

        assert_equal 'Speed',      first.reasoning
        assert_equal :pattern,     first.category
        assert_nil                 second.reasoning
        assert_equal :observation, second.category
        assert_equal [[1, 2]], @node_source.queries
      end

      def test_recall_defaults_when_node_has_no_stored_metadata
        @fake_htm.stub_nodes([FakeHTM.raw_row(id: 9, content: 'Loaded from a file')])
        entry = @adapter.recall(query: 'file').first
        assert_nil entry.reasoning
        assert_equal :fact, entry.category
      end

      def test_recall_does_not_mutate_htm_rows
        row = FakeHTM.raw_row(id: 1, content: 'c')
        @fake_htm.stub_nodes([row])
        build_adapter(1 => { 'category' => 'fact' }).recall(query: 'c')
        refute row.key?('metadata')
      end

      def test_recall_skips_lookup_when_rows_already_carry_metadata
        row = FakeHTM.raw_row(id: 1, content: 'c').merge('metadata' => { 'category' => 'correction' })
        @fake_htm.stub_nodes([row])
        entry = @adapter.recall(query: 'c').first
        assert_equal :correction, entry.category
        assert_empty @node_source.queries
      end

      def test_metadata_for_returns_plain_hashes_keyed_by_node_id
        adapter = build_adapter(3 => { 'reasoning' => 'r', 'category' => 'fact' })
        assert_equal({ 3 => { 'reasoning' => 'r', 'category' => 'fact' } }, adapter.metadata_for([3, 4]))
      end

      def test_metadata_for_empty_ids_makes_no_query
        assert_equal({}, @adapter.metadata_for([]))
        assert_empty @node_source.queries
      end

      def test_with_metadata_fills_in_missing_metadata
        node = @adapter.with_metadata({ 'id' => 5 }, { 5 => { 'category' => 'pattern' } })
        assert_equal({ 'category' => 'pattern' }, node['metadata'])
      end

      def test_node_source_returns_injected_source
        assert_same @node_source, @adapter.node_source
      end

      def test_recall_passes_strategy_and_limit_to_htm
        @adapter.recall(query: 'test', limit: 5, strategy: :fulltext)
        args = @fake_htm.last_recall_args
        assert_equal 5,         args[:limit]
        assert_equal :fulltext, args[:strategy]
        assert_equal true,      args[:raw]
      end

      def test_recall_defaults_to_hybrid_strategy
        @adapter.recall(query: 'test')
        assert_equal :hybrid, @fake_htm.last_recall_args[:strategy]
      end

      def test_recall_returns_empty_array_when_no_nodes
        entries = @adapter.recall(query: 'nothing')
        assert_empty entries
        assert_empty @node_source.queries
      end

      def test_htm_accessor_exposes_underlying_htm_instance
        assert_same @fake_htm, @adapter.htm
      end
    end
  end
end
