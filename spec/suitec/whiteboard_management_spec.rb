require_relative '../../util/spec_helper'

describe 'Whiteboard', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['course_id']

    # Load test data
    user_test_data = Utils.load_test_users.select { |data| data['tests']['whiteboardManagement'] }
    @teacher = User.new user_test_data.find { |data| data['role'] == 'Teacher' }
    students_data = user_test_data.select { |data| data['role'] == 'Student' }
    @student_1 = User.new students_data[0]
    @student_2 = User.new students_data[1]
    @student_3 = User.new students_data[2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, [@teacher, @student_1, @student_2, @student_3], test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX, SuiteCTools::WHITEBOARDS])

    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @whiteboards_url = @canvas.click_tool_link(@driver, SuiteCTools::WHITEBOARDS)
  end

  after(:all) { @driver.quit }

  describe 'creation' do

    before(:all) do
      @whiteboard = Whiteboard.new({ owner: @student_1, title: "Whiteboard Creation #{test_id}", collaborators: [] })
      @canvas.masquerade_as(@student_1, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
    end

    before(:each) do
      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url)
    end

    it 'shows a Create Your First Whiteboard link if the user has no existing whiteboards' do
      create_first_link = @whiteboards.verify_block { @whiteboards.create_first_whiteboard_link_element.when_visible timeout }
      @whiteboards.list_view_whiteboard_elements.any? ?
          (expect(create_first_link).to be false) :
          (expect(create_first_link).to be true)
    end

    it 'requires a title' do
      @whiteboards.click_add_whiteboard
      @whiteboards.click_create_whiteboard
      @whiteboards.title_req_msg_element.when_visible timeout
    end

    it 'permits a title with 255 characters maximum' do
      @whiteboards.click_add_whiteboard
      @whiteboards.enter_whiteboard_title "#{'A loooooong title' * 15}?"
      @whiteboards.click_create_whiteboard
      @whiteboards.title_max_length_msg_element.when_visible timeout
    end

    it 'can be done with the owner as the only member' do
      @whiteboard.title = "#{@whiteboard.title} with owner only"
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard)
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end

    it 'can be done with the owner plus other course site members as whiteboard members' do
      @whiteboard.title = "#{@whiteboard.title} plus members"
      @whiteboard.collaborators = [@student_2, @teacher]
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard)
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end
  end

  describe 'editing' do

    before(:all) do
      editing_test_id = "#{Time.now.to_i}"
      @whiteboard = Whiteboard.new({ owner: @student_1, title: "Whiteboard Editing #{editing_test_id}", collaborators: [] })
      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url)
    end

    it 'allows the title to be changed' do
      @whiteboard.title = "#{@whiteboard.title} before edit"
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard)
      @whiteboard.title = "#{@whiteboard.title} after edit"
      @whiteboards.edit_whiteboard_title @whiteboard
      # Verify the page title is updated with the new whiteboard title
      @whiteboards.wait_until(timeout) { @whiteboards.title == @whiteboard.title }
      @whiteboards.close_whiteboard @driver
      # Verify the whiteboard list view shows the new whiteboard title
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.verify_first_whiteboard @whiteboard
    end
  end

  describe 'search' do

    before(:all) do
      @search_test_id = "#{Time.now.to_i}"
      @whiteboard_1 = Whiteboard.new({ owner: @student_1, title: "Whiteboard Search #{@search_test_id} Unique Title", collaborators: [] })
      @whiteboard_2 = Whiteboard.new({ owner: @student_1, title: "Whiteboard Search #{@search_test_id} Non-unique Title", collaborators: [@teacher] })
      @whiteboard_3 = Whiteboard.new({ owner: @student_1, title: "Whiteboard Search #{@search_test_id} Non-unique Title", collaborators: [@teacher, @student_2] })

      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url)
      [@whiteboard_1, @whiteboard_2, @whiteboard_3].each { |whiteboard| @whiteboards.create_whiteboard whiteboard }
    end

    it ('is not available to a student') { expect(@whiteboards.simple_search_input?).to be false }

    it 'is available to a teacher' do
      @canvas.masquerade_as(@teacher, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.simple_search_input_element.when_visible timeout
    end

    it 'allows a teacher to perform a simple search by title that returns results' do
      @whiteboards.simple_search "#{@search_test_id}"
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 3 }
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform a simple search by title that returns no results' do
      @whiteboards.simple_search 'foo'
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end

    it 'allows a teacher to perform an advanced search by title that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", nil)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 2 }
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by title that returns no results' do
      @whiteboards.advanced_search('bar', nil)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns results' do
      @whiteboards.advanced_search(nil, @student_1)
      # Search could return whiteboards from other test runs, so just verify that those from this run are present too
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length > 3 }
      @whiteboards.wait_until(timeout) { (@whiteboards.visible_whiteboard_titles & [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title]).length == 2 }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns no results' do
      @whiteboards.advanced_search(nil, @student_3)
      @whiteboards.wait_until(timeout) { !@whiteboards.visible_whiteboard_titles.include? (@whiteboard_1.title || @whiteboard_2.title || @whiteboard_3.title) }
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Unique Title", @student_1)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 3 }
      # Expect all 3 whiteboards since all contain the components of the search string
      @whiteboards.wait_until(timeout) { (@whiteboards.visible_whiteboard_titles.sort) == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns no results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", @student_3)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end
  end

  describe 'export' do

    before(:all) do
      export_test_id = "#{Time.now.to_i}"
      @whiteboard = Whiteboard.new({ owner: @student_1, title: "Whiteboard Export #{export_test_id}", collaborators: [] })

      # Upload assets to be used on whiteboard
      @canvas.masquerade_as(@student_1, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      user_asset_data = @student_1.assets
      @assets = []
      user_asset_data.each do |data|
        asset = Asset.new data
        (data['type'] == 'File') ? @asset_library.upload_file_to_library(asset) : @asset_library.add_site(asset)
        @asset_library.wait_until do
          @asset_library.list_view_asset_title_elements.any?
          @asset_library.list_view_asset_title_elements[0].text == asset.title
          asset.id = @asset_library.list_view_asset_ids.first
          @assets << asset
        end
      end

      # Get current score
      @canvas.masquerade_as(@teacher, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @student_1
      @initial_score = @engagement_index.user_score @student_1

      # Get configured points per activity
      @engagement_index.click_points_config
      @add_asset_to_board_points = "#{@engagement_index.activity_points Activities::ADD_ASSET_TO_WHITEBOARD}"
      @export_board_points = "#{@engagement_index.activity_points Activities::EXPORT_WHITEBOARD}"

      # Determine expected scores after activities
      @score_with_add_asset = @initial_score.to_i + (@add_asset_to_board_points.to_i * @assets.length)
      @score_with_export_whiteboard = @score_with_add_asset + @export_board_points.to_i

      # Create a whiteboard for tests
      @canvas.masquerade_as(@student_1, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard)
    end

    it 'is not possible if the whiteboard has no assets' do
      @whiteboards.click_export_button
      @whiteboards.export_to_library_button_element.when_visible timeout
      expect(@whiteboards.export_to_library_button_element.attribute('disabled')).to eql('true')
      expect(@whiteboards.download_as_image_button_element.attribute('disabled')).to eql('true')
    end

    it 'as a new asset is possible if the whiteboard has assets' do
      whiteboard_as_asset = Asset.new({title: "#{@whiteboard.title}"})
      @whiteboards.add_existing_assets @assets
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      @whiteboards.export_to_asset_library @whiteboard
      @whiteboards.wait_until { @whiteboards.export_confirm_msg? }
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.verify_first_asset(@student_1, whiteboard_as_asset)
    end

    it 'as a new asset earns "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as(@teacher, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @student_1
      expect(@engagement_index.user_score @student_1).to eql("#{@score_with_export_whiteboard}")
    end

    it 'as a new asset shows "export_whiteboard" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@student_1.full_name}, #{Activities::ADD_ASSET_TO_WHITEBOARD.type}, #{@add_asset_to_board_points}, #{@score_with_add_asset}")
      expect(scores).to include("#{@student_1.full_name}, #{Activities::EXPORT_WHITEBOARD.type}, #{@export_board_points}, #{@score_with_export_whiteboard}")
    end

    it 'as a PNG download is possible if the whiteboard has assets' do
      @canvas.masquerade_as(@student_1, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @whiteboards.download_as_image
      expect(@whiteboards.verify_image_download @whiteboard).to be true
    end

    it 'as a PNG download earns no "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as(@teacher, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @student_1
      expect(@engagement_index.user_score @student_1).to eql("#{@score_with_export_whiteboard}")
    end
  end
end
