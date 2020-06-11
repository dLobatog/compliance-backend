# frozen_string_literal: true

module Api
  module V1
    module Schemas
      module Profiles
        PROFILE = {
          type: 'object',
          required: %w[name ref_id],
          properties: {
            parent_profile_id: {
              type: 'string',
              format: 'uuid',
              nullable: true,
              example: '0105a0f0-7379-4897-a891-f95cfb9ddf9c'
            },
            parent_profile_ref_id: {
              type: 'string',
              nullable: true,
              example: 'xccdf_org.ssgproject.content_profile_standard'
            },
            description: {
              type: 'string',
              nullable: true,
              example: 'This profile contains rules to ensure standard '\
              'security baseline\nof a Red Hat Enterprise Linux 7 '\
              'system. Regardless of your system\'s workload\nall '\
              'of these checks should pass.'
            },
            compliance_threshold: {
              type: 'number',
              example: 95.0
            },
            score: {
              type: 'number',
              example: 63.154762
            },
            business_objective: {
              type: 'string',
              example: 'APAC Expansion',
              nullable: true
            },
            canonical: {
              type: 'boolean',
              example: true
            },
            compliant_host_count: {
              type: 'integer',
              example: 3
            },
            external: {
              type: 'boolean',
              example: false
            },
            tailored: {
              type: 'boolean',
              example: false
            },
            total_host_count: {
              type: 'integer',
              example: 5
            },
            os_major_version: {
              type: 'string',
              example: '7'
            }
          }
        }.freeze
      end
    end
  end
end