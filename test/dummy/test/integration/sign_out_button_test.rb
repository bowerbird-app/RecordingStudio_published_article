# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class SignOutButtonTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
  end

  test "home page nav Sign out is a FlatPack link with href and turbo delete" do
    sign_in @user

    get root_path

    assert_response :success
    assert_select "a[href=?][data-turbo-method='delete']", destroy_user_session_path do |links|
      assert_includes links.first.text, "Sign out"
    end
    refute_includes response.body, 'url="/users/sign_out"'
    refute_select "button[url]"
  end

  test "signing out through the session destroy path returns to sign in" do
    sign_in @user
    get root_path
    assert_response :success

    delete destroy_user_session_path
    follow_redirect!

    get root_path
    assert_redirected_to new_user_session_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Login"
  end
end
