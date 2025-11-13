require "test_helper"

class MemesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get memes_index_url
    assert_response :success
  end

  test "should get show" do
    get memes_show_url
    assert_response :success
  end

  test "should get random" do
    get memes_random_url
    assert_response :success
  end

  test "should get search" do
    get memes_search_url
    assert_response :success
  end

  test "should get trending" do
    get memes_trending_url
    assert_response :success
  end
end
