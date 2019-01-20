# frozen_string_literal: true

# Receives messages from the Kafka topic, converts them into jobs
# for processing
class ComplianceReportsConsumer < ApplicationConsumer
  subscribes_to Settings.platform_kafka_topic

  def process(message)
    @value = JSON.parse(message.value)
    logger.info "Received message, enqueueing: #{message.value}"
    path = "tmp/storage/#{@value['payload_id']}"
    enqueue_job(path)
  rescue SafeDownloader::DownloadError => error
    logger.error "Error parsing report: #{@value['payload_id']}"\
      " - #{error.message}"
    send_validation('failure')
  end

  def send_validation(validation)
    produce(
      validation_payload(@value['payload_id'], validation),
      topic: Settings.platform_kafka_validation_topic
    )
  end

  private

  def enqueue_job(path)
    if validate(path) == 'success'
      job = ParseReportJob.perform_later(
        path,
        @value['account'],
        @value['b64_identity']
      )
      logger.info "Message enqueued: #{@value['payload_id']} as #{job.job_id}"
    else
      logger.error "Error parsing report: #{@value['payload_id']}"
    end
  end

  def validate(path)
    SafeDownloader.download(@value['url'], path)
    message = validation_message(path)
    send_validation(message)
    message
  end

  def validation_message(path)
    XCCDFReportParser.new(path, @value['account'], @value['b64_identity'])
    'success'
  rescue StandardError => error
    logger.error "Error validating report: #{@value['payload_id']}"\
      " - #{error.message}"
    'failure'
  end

  def validation_payload(payload_id, result)
    {
      'payload_id': payload_id,
      'service': 'compliance',
      'validation': result
    }.to_json
  end

  def logger
    Rails.logger
  end
end
