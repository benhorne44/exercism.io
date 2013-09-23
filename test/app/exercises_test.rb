require './test/app_helper'
require 'mocha/setup'

class ExercisesTest < Minitest::Test
  include Rack::Test::Methods

  def app
    ExercismApp
  end

  def teardown
    clear_cookies
  end

  def setup
    super
    @alice = User.create(username: 'alice', github_id: 1, email: 'alice@example.com')
  end

  def logged_in
    { github_id: @alice.github_id }
  end

  def test_exercise_gallery
    User.any_instance.expects(:completed?).returns(true)
    alice = User.create(username: 'alice', github_id: 1, email: 'alice@example.com')
    set_cookie("_exercism_login=#{alice.github_id}")
    get "/completed/ruby/bob"
    assert_equal 200, last_response.status
  end

end
