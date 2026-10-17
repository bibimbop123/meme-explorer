# frozen_string_literal: true

# AuthHelpers — Centralized authentication and authorization helpers
#
# Replaces 347 scattered `session[:user_id]` checks with clean, consistent macros.
#
# Usage in route handlers:
#   require_auth!                  # Halts with 401/redirect if not logged in
#   require_admin!                 # Halts with 403 if not admin
#   current_user                   # Returns user hash or nil
#   logged_in?                     # Returns true/false
#   current_user_id                # Returns integer user id or nil

module AuthHelpers
  # Browsing continuity, not authentication or cross-device identity. Never use
  # an IP address or user-supplied query parameter as the history namespace.
  def feed_session_id
    existing = session[:feed_session_id]
    return existing if existing.is_a?(String) && existing.match?(/\A[a-f0-9]{64}\z/)
    session[:feed_session_id] = SecureRandom.hex(32)
  end

  def pending_save_target(pending)
    return nil unless pending.is_a?(Hash) && pending['id'].is_a?(String) &&
                      pending['id'].match?(/\A[a-f0-9]{64}\z/) &&
                      pending['expires_at'].to_i > Time.now.to_i
    "/meme/#{pending['id']}?save_after_login=1"
  end

  # Called only after successful authentication and session rotation. Resolve
  # the server-held identity again; never save from redirect/query parameters.
  def complete_pending_save(pending)
    return nil unless current_user_id
    target = pending_save_target(pending)
    return nil unless target
    meme = MemeIdentityService.find(pending['id'])
    return target unless meme

    result = EngagementService.track_save(
      user_id: current_user_id, meme_url: meme['url'],
      title: meme['title'], subreddit: meme['subreddit'],
      saved_now: true, session: session, db: ::DB
    )
    AppLogger.warn('Post-login save not confirmed') unless result[:success]
    target
  rescue => e
    # Login remains successful; the destination offers a manual retry and
    # reports the actual persisted saved state instead of claiming success.
    AppLogger.warn('Post-login save unavailable', error: e.class.name)
    target
  end

  # Returns the current user's DB record (memoized per request).
  # Returns nil if not logged in or user not found.
  def current_user
    return @current_user if defined?(@current_user)
    uid = session[:user_id]
    return (@current_user = nil) unless uid

    @current_user = begin
      UserService.find_by_id(uid.to_i)
    rescue => e
      AppLogger.warn("current_user lookup failed", error: e.message, user_id: uid)
      nil
    end
  end

  # Returns the integer user id from the session, or nil.
  def current_user_id
    session[:user_id]&.to_i
  end

  # Returns true if a user is logged in and found in the DB.
  def logged_in?
    !current_user.nil?
  end

  # Halts the request if the user is not authenticated.
  # JSON clients get 401 JSON; browser clients get redirected to /login.
  def require_auth!
    return if logged_in?

    if json_request?
      halt 401, { error: 'Authentication required' }.to_json
    else
      session[:return_to] = request.path
      redirect '/login'
    end
  end

  # Halts with 403 if the current user is not an admin.
  # Implicitly calls require_auth! first.
  def require_admin!
    require_auth!
    unless UserService.is_admin?(current_user_id)
      halt 403, json_request? ? { error: 'Forbidden' }.to_json : 'Forbidden'
    end
  end

  # Redirect to the originally requested page after login, or a default.
  def redirect_after_login(default: '/')
    target = session.delete(:return_to) || default
    redirect target
  end

  private

  # True when the client wants JSON (XHR or explicit Accept header).
  def json_request?
    # BUG FIX: this only ever checked XHR/Accept/Content-Type headers, so
    # a request to a URL that's unambiguously a JSON API by its own path
    # convention (e.g. `/metrics.json`, `/trending.json`, `/api/...`) but
    # sent without those specific headers - like a plain `fetch()` call
    # with no extra options, or a test hitting the path directly - still
    # got a 302 redirect to `/login` from require_auth! instead of a JSON
    # 401 body. A JS client parsing the response as JSON would then choke
    # on the redirect/HTML instead of getting a clean 401 it can handle.
    request.xhr? ||
      request.env['HTTP_ACCEPT'].to_s.include?('application/json') ||
      request.content_type.to_s.include?('application/json') ||
      request.path.end_with?('.json') ||
      request.path.start_with?('/api/')
  end
end
