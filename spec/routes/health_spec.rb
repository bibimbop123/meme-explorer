require_relative "../../spec/spec_helper"

describe "Health Monitoring Routes" do
  describe "GET /health" do
    it "returns 200 OK" do
      get "/health"
      expect(last_response.status).to eq(200)
    end
    
    it "returns JSON with health status" do
      get "/health"
      data = JSON.parse(last_response.body)
      expect(data["status"]).to eq("ok")
      expect(data).to have_key("timestamp")
      expect(data).to have_key("uptime_seconds")
      expect(data).to have_key("requests")
      expect(data).to have_key("avg_response_time_ms")
      expect(data).to have_key("error_rate_5m")
    end
    
    it "tracks request count" do
      get "/health"
      data1 = JSON.parse(last_response.body)
      initial_requests = data1["requests"]
      
      get "/health"
      data2 = JSON.parse(last_response.body)
      new_requests = data2["requests"]
      
      expect(new_requests).to be > initial_requests
    end
  end

  describe "GET /errors (admin only)" do
    it "returns 403 to non-admin users" do
      get "/errors"
      expect(last_response.status).to eq(403)
    end
  end
end
