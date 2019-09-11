# frozen_string_literal: true

require 'uri'
require 'json'

# Interact with the Insights Host Inventory. Usually HTTP calls
# are all that's needed.
class HostInventoryAPI
  def initialize(host, account, url, b64_identity)
    @host = host
    @url = "#{URI.parse(url)}#{ENV['PATH_PREFIX']}/inventory/v1/hosts"
    @account = account
    @b64_identity = b64_identity
  end

  def host_already_in_inventory
    response = Platform.connection.get(
      @url, {}, 'X_RH_IDENTITY' => @b64_identity
    )
    find_results(JSON.parse(response.body))
  end

  def create_host_in_inventory
    response = Platform.connection.post(@url) do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['X_RH_IDENTITY'] = @b64_identity
      req.body = create_host_body
    end

    JSON.parse(response.body).dig('data')&.first&.dig('host')
  end

  def sync
    inventory_host = host_already_in_inventory || create_host_in_inventory
    @host.id ||= inventory_host.dig('id')
    @host.save
    @host
  end

  private

  def find_results(body)
    body['results'].find do |host|
      (host['id'] == @host.id || host['fqdn'] == @host.name) &&
        host['account'] == @account.account_number
    end
  end

  def create_host_body
    [{
      'facts': [{ 'facts': { 'fqdn': @host.name }, 'namespace': 'inventory' }],
      'fqdn': @host.name,
      'display_name': @host.name,
      'account': @account.account_number
    }].to_json
  end
end
