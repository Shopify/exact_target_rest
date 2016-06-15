module ExactTargetRest
  class TriggeredSend
    # Execute TriggeredSends to one or several subscribers.
    #
    # @param authorization [Authorization]
    # @param external_key [String] The string that identifies the TriggeredSend
    # @param snake_to_camel [Boolean] Attributes should be converted to CamelCase? (default true)
    def initialize(authorization, external_key, snake_to_camel: true)
      @authorization = authorization
      @external_key = external_key
      @snake_to_camel = snake_to_camel
    end

    # TriggeredSend for just one subscriber.
    # @param to_address [String] Email to send.
    # @param subscriber_key [String] SubscriberKey (it uses Email if not set).
    # @param data_extension_attributes [{Symbol => Object}] List of attributes (in snake_case)
    #   that will be used in TriggeredSend and will be saved in related DataExtension
    #   (in CamelCase).
    def send_one(
      email_address:,
      subscriber_key: email_address,
      ** data_extension_attributes
      )
      deliver(
        email_address: email_address,
        subscriber_key: subscriber_key,
        subscriber_attributes: prepare_attributes(data_extension_attributes)
      )
    end

    # TriggeredSend for just one subscriber.
    # @param request_type [String] ASYNC or SYNC.
    # @param to_address [String] Email to send.
    # @param subscriber_key [String] SubscriberKey.
    # => it uses Email if not set
    # @param from_address [String] Sender email address.
    # @param from_name [String] Sender name.
    # @param subscriber_attributes [{String => String, ...}] List of attributes
    # => Keys as Strings (when your ExactTarget's fields doesn't have a pattern)
    def deliver(
      request_type: "ASYNC",
      email_address:,
      subscriber_key: email_address,
      from_address: "",
      from_name: "",
      subscriber_attributes: {}
      )
      @authorization.with_authorization do |access_token|
        resp = endpoint.post do |p|
          p.url(format(TRIGGERED_SEND_PATH, URI.encode(@external_key)))
          p.headers['Authorization'] = "Bearer #{access_token}"
          p.body = {
            From: {
              Address: from_address,
              Name: from_name
            },
            To: {
              Address: email_address,
              SubscriberKey: subscriber_key,
              ContactAttributes: {
                  SubscriberAttributes: subscriber_attributes
              }
            },
            OPTIONS: {
              RequestType: request_type
            }
          }
        end
        raise NotAuthorizedError if resp.status == 401
        resp
      end
    end

    protected

    def endpoint
      @endpoint ||= Faraday.new(url: TRIGGERED_SEND_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter FARADAY_ADAPTER
      end
    end

    def prepare_attributes(attributes)
      @snake_to_camel ? attributes.snake_to_camel : attributes
    end
  end
end
