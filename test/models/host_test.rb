# frozen_string_literal: true

require 'test_helper'

class HostTest < ActiveSupport::TestCase
  should validate_presence_of :name

  test 'compliant returns a hash with all compliance statuses' do
    host = hosts(:one)
    host.profiles << [profiles(:one), profiles(:two)]
    expected_result = {
      profiles(:one).ref_id.to_s => false,
      profiles(:two).ref_id.to_s => false
    }
    assert_equal expected_result, host.compliant
  end

  context 'external methods for search' do
    setup do
      @host = hosts(:one)
      @host.profiles << profiles(:one)
      rules(:one).profiles << profiles(:one)
      rules(:two).profiles << profiles(:one)
      test_results(:one).update(host: hosts(:one), profile: profiles(:one))
      RuleResult.create(host: @host, rule: rules(:one),
                        test_result: test_results(:one), result: 'pass')
      RuleResult.create(host: @host, rule: rules(:two),
                        test_result: test_results(:one), result: 'fail')
    end

    should 'total_rules returns the number of rules' do
      assert_equal 2, @host.last_scan_results.count
    end

    should 'rules_passed returns the number of rules that passed' do
      assert_equal 1, @host.rules_passed
    end

    should 'rules_failed returns the number of rules that failed' do
      assert_equal 1, @host.rules_failed
    end

    should 'compliance_score returns the percentage of rules that passed' do
      assert_equal 50.0, @host.compliance_score
    end

    should 'be able to find based on compliance score' do
      assert_includes(
        Host.search_for('compliance_score >= 40 and compliance_score <= 60'),
        hosts(:one)
      )
      assert_not_includes(
        Host.search_for('compliance_score >= 0 and compliance_score <= 39'),
        hosts(:one)
      )
    end

    should 'be able to find based on compliance true/false' do
      assert_not_includes Host.search_for('compliant = true'), hosts(:one)
      assert_includes Host.search_for('compliant = false'), hosts(:one)
      assert_includes Host.search_for('compliant != true'), hosts(:one)
      assert_not_includes Host.search_for('compliant != false'), hosts(:one)
    end

    should 'be able to filter by "has test results"' do
      assert hosts(:one).test_results.present?
      assert hosts(:two).test_results.empty?
      assert_includes Host.search_for('has_test_results = true'), hosts(:one)
      assert_not_includes(Host.search_for('has_test_results = true'),
                          hosts(:two))
      assert_includes Host.search_for('has_test_results = false'), hosts(:two)
      assert_not_includes(Host.search_for('has_test_results = false'),
                          hosts(:one))
      assert_includes Host.search_for('has_test_results != true'), hosts(:two)
      assert_not_includes(Host.search_for('has_test_results != true'),
                          hosts(:one))
      assert_includes Host.search_for('has_test_results != false'), hosts(:one)
      assert_not_includes(Host.search_for('has_test_results != false'),
                          hosts(:two))
    end
  end
end
