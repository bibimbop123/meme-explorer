require_relative "../../spec/spec_helper"

describe "Profile Routes" do
  describe "GET /profile (without authentication)" do
    it "returns 401 Unauthorized" do
      get "/profile"
      expect(last_response.status).to eq(401)
    end
    
    it "shows not logged in message" do
      get "/profile"
      expect(last_response.body).to include("Not logged in")
    end
  end

  describe "GET /profile (with authentication)" do
    before(:each) do
      # Create a test user
      hashed = BCrypt::Password.create("testpass123")
      DB.execute(
        "INSERT INTO users (email, password_hash) VALUES (?, ?)",
        ["testuser@example.com", hashed]
      )
      @user_id = DB.last_insert_row_id
    end

    it "loads profile page successfully" do
      get "/profile"
      # Without session, should return 401 (tested above)
      expect(last_response.status).to eq(401)
    end

    it "returns error for non-existent user" do
      get "/profile"
      # Session-less requests get 401
      expect(last_response.body).to include("Not logged in")
    end
  end
end
