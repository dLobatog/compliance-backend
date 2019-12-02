# frozen_string_literal: true

module Types
  # Definition of the Profile type in GraphQL
  class Profile < Types::BaseObject
    graphql_name 'Profile'
    description 'A Profile registered in Insights Compliance'

    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :ref_id, String, null: false
    field :compliance_threshold, Float, null: false
    field :rules, [::Types::Rule], null: true, extras: [:lookahead] do
      argument :system_id, String,
               'System ID to filter by', required: false
      argument :identifier, String,
               'Rule identifier to filter by', required: false
      argument :references, [String],
               'Rule references to filter by', required: false
    end

    field :hosts, [::Types::System], null: true
    field :business_objective, ::Types::BusinessObjective, null: true
    field :business_objective_id, ID, null: true
    field :total_host_count, Int, null: false

    field :compliant, Boolean, null: false do
      argument :system_id, String, 'Is a system compliant?', required: false
    end

    field :rules_passed, Int, null: false do
      argument :system_id, String,
               'Rules passed for a system and a profile', required: false
    end

    field :rules_failed, Int, null: false do
      argument :system_id, String,
               'Rules failed for a system and a profile', required: false
    end

    field :last_scanned, String, null: false do
      argument :system_id, String,
               'Last time this profile was scanned for a system',
               required: false
    end

    field :compliant_host_count, Int, null: false

    # rubocop:disable AbcSize
    def rules(args = {})
      context[:parent_profile_id] ||= {}
      context[:rule_results] ||= {}
      latest_test_result_batch(args).then do |latest_test_result|
        ::CollectionLoader.for(::TestResult, :rule_results).load(latest_test_result).then do |rule_results|
          grouped_rules_references = ::RuleReferencesRule.where(rule_id: rule_results.pluck(:rule_id)).group_by(&:rule_id)
          grouped_rules_references.each do |rule_id, references|
            context[:"rule_references_#{rule_id}"] = references.pluck(:rule_reference_id)
          end
          if rule_results.blank?
            []
          else
            ::RecordLoader.for(::Rule).load_many(rule_results.pluck(:rule_id)).then do |rules|
              rules.each do |rule|
                context[:parent_profile_id][rule.id] = object.id
              end
              rule_results.each do |rule_result|
                context[:rule_results][rule_result.rule_id] ||= {}
                context[:rule_results][rule_result.rule_id][object.id] = rule_result.result
              end
              rules
            end
          end
        end
      end
      #selected_columns = (args[:lookahead].selections.map(&:name) &
      #                   ::Rule.column_names.map(&:to_sym)) << :id
      #CollectionLoader.for(object.class, :rules).load(object).then do |rules|
      #  RecordLoader.for(Host).load(system_id(args)).then do |host|
      #j    rules = object.rules_for_system(host, selected_columns) if host.present?
      #    rules = object.rules.select(selected_columns) if host.blank?
      #    rules = rules.with_identifier(args[:identifier]) if args.dig(:identifier)
      #    rules = rules.with_references(args[:references]) if args.dig(:references)
      #    rules = lookahead_includes(args[:lookahead], rules,
      #                               identifier: :rule_identifier)
      #    rules
      #  end
      #end
    end
    # rubocop:enable AbcSize

    def compliant_host_count
      CollectionLoader.for(object.class, :hosts).load(object).then do |hosts|
        hosts.count { |host| object.compliant?(host) }
      end
    end

    def total_host_count
      CollectionLoader.for(object.class, :hosts).load(object).then do |hosts|
        hosts.count
      end
    end

    def compliant(args = {})
      latest_test_result_batch(args).then do |latest_test_result|
        host_results = latest_test_result&.rule_results
        host_results.present? &&
          (host_results.count(true) / host_results.count.to_f) >=
          (object.compliance_threshold / 100.0)
      end
    end

    def rules_passed(args = {})
      latest_test_result_batch(args).then do |latest_test_result|
        latest_test_result&.rule_results.where(result: %w[pass notapplicable notselected]).count
      end
    end

    def rules_failed(args = {})
      latest_test_result_batch(args).then do |latest_test_result|
        latest_test_result&.rule_results.where.not(result: %w[pass notapplicable notselected]).count
      end
    end

    def last_scanned(args = {})
      latest_test_result_batch(args).then do |latest_test_result|
        latest_test_result.end_time&.iso8601 || 'Never'
      end
    end

    private

    def system_id(args)
      args[:system_id] || context[:parent_system_id]
    end

    def latest_test_result_batch(args)
      ::RecordLoader.for(
        ::TestResult,
        column: :profile_id,
        where: { host_id: system_id(args) },
        order: 'created_at DESC',
        includes: [:rule_results]
      ).load(object.id)
    end
  end
end
