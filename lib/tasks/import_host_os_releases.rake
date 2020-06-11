# frozen_string_literal: true

desc <<-END_DESC
  Imports the os_release field from the system_profile stored in the Inventory.

  Examples:
    # JOBS_ACCOUNT_NUMBER=000001 rake import_host_os_releases
END_DESC

task import_host_os_releases: :environment do
  begin
    start_time = Time.now.utc
    puts "Starting import_host_os_releases job at #{start_time}"
    inventory_api = HostInventoryAPI.new(
      Account.find_by!(account_number: ENV['JOBS_ACCOUNT_NUMBER'])
    )
    ::Host.find_in_batches(batch_size: 50) do |hosts|
      begin
        inventory_api.import_os_releases(hosts.pluck(:id))
      rescue Faraday::ClientError => e
        Rails.logger.info("#{e.message} #{e.response}")
      end
    end
    end_time = Time.now.utc
    duration = end_time - start_time
    puts "Finishing import_host_os_releases job at #{end_time} "\
         "and last #{duration} seconds"
  rescue StandardError => e
    ExceptionNotifier.notify_exception(
      e,
      data: OpenshiftEnvironment.summary
    )
  end
end