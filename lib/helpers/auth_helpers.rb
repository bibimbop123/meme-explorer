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
    request.xhr? ||
      request.env['HTTP_ACCEPT'].to_s.include?('application/json') ||
      request.content_type.to_s.include?('application/json')
  end
end
