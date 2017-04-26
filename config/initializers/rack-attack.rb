class Rack::Attack
  class Request < ::Rack::Request
    # get user id from access_token
    # Note: access_token should be present. If not present, request is not throttled.
    def user_id
      return env["attack.user_id"] if env["attack.user_id"]

      token = params['access_token']
      access_token = Doorkeeper::AccessToken.where(token: token).first
      user = User.find(access_token.resource_owner_id)
      env["attack.user_id"] = user.id
      return user.id
    end
  end

  ### Configure Cache ###

  # If you don't want to use Rails.cache (Rack::Attack's default), then
  # configure it here.
  #
  # Note: The store is only used for throttling (not blacklisting and
  # whitelisting). It must implement .increment and .write like
  # ActiveSupport::Cache::Store

  # Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new 

  ### Safelist Requests ###

  # Safelist any request not to API or does not have access_token
  safelist('allow from localhost') do |req|
    (not req.path.start_with?("/api/")) || (not req.params['access_token'])
  end

  ### Throttle Requests ###

  # Throttle all requests by user id
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/general:#{req.user_id}"
  throttle('api/general', :limit => 10, :period => 30.seconds) do |req|
    req.user_id
  end

  # Throttle requests for assessment submission endpoint
  #
  # Key: "rack::attack:#{Time.now.to_i/:period}:api/submit:#{req.user_id}"
  throttle("api/submit", :limit => 4, :period => 1.minute) do |req|
    if req.path.end_with?("submit")
      req.user_id
    end
  end

  ### Custom Throttle Response ###

  # By default, Rack::Attack returns an HTTP 429 for throttled responses,
  # which is just fine.
  #
  # If you want to return 503 so that the attacker might be fooled into
  # believing that they've successfully broken your app (or you just want to
  # customize the response), then uncomment these lines.
  # self.throttled_response = lambda do |env|
  #  [ 503,  # status
  #    {},   # headers
  #    ['']] # body
  # end
end