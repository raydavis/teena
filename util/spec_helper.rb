require 'rspec'
require 'rspec/core/rake_task'
require 'logger'
require 'csv'
require 'json'
require 'selenium-webdriver'
require 'page-object'
require 'fileutils'
require 'pg'

require_relative '../models/user'
require_relative '../models/boac/alert'
require_relative '../models/boac/cohort'
require_relative '../models/boac/curated_cohort'
require_relative '../models/boac/filtered_cohort'
require_relative '../models/boac/cohort_search_criteria'
require_relative '../models/boac/team'
require_relative '../models/boac/squad'
require_relative '../models/course'
require_relative '../models/analytics/event'
require_relative '../models/analytics/event_type'
require_relative '../models/section'
require_relative '../models/lti_tools'
require_relative '../models/canvas/announcement'
require_relative '../models/canvas/assignment'
require_relative '../models/canvas/discussion'
require_relative '../models/canvas/group'
require_relative '../models/oec/oec_departments'
require_relative '../models/suitec/activity'
require_relative '../models/suitec/asset'
require_relative '../models/suitec/comment'
require_relative '../models/suitec/whiteboard'

require_relative '../logging'
require_relative 'utils'
require_relative 'boac_utils'
require_relative 'junction_utils'
require_relative 'lrs_utils'
require_relative 'oec_utils'
require_relative 'suite_c_utils'
require_relative '../pages/page'
require_relative '../pages/oec/blue_page'
require_relative '../pages/cal_net_page'
require_relative '../pages/canvas/canvas_page'
require_relative '../pages/canvas/canvas_assignments_page'
require_relative '../pages/canvas/canvas_announce_discuss_page'
require_relative '../pages/canvas/canvas_grades_page'
require_relative '../pages/canvas/canvas_groups_page'
require_relative '../pages/junction/junction_pages'
require_relative '../pages/junction/api_academics_course_provision_page'
require_relative '../pages/junction/api_academics_roster_page'
require_relative '../pages/junction/splash_page'
require_relative '../pages/junction/my_toolbox_page'
require_relative '../pages/junction/canvas_course_sections_page'
require_relative '../pages/junction/canvas_site_creation_page'
require_relative '../pages/junction/canvas_create_course_site_page'
require_relative '../pages/junction/canvas_create_project_site_page'
require_relative '../pages/junction/canvas_course_add_user_page'
require_relative '../pages/junction/canvas_course_captures_page'
require_relative '../pages/junction/canvas_rosters_page'
require_relative '../pages/junction/canvas_course_manage_sections_page'
require_relative '../pages/junction/canvas_mailing_lists_page'
require_relative '../pages/junction/canvas_mailing_list_page'
require_relative '../pages/junction/canvas_e_grades_export_page'
require_relative '../pages/boac/boac_pages'
require_relative '../pages/boac/home_page'
require_relative '../pages/boac/cohort_pages'
require_relative '../pages/boac/curated_cohort_page'
require_relative '../pages/boac/curated_cohort_list_view_page'
require_relative '../pages/boac/filtered_cohort_page'
require_relative '../pages/boac/filtered_cohort_list_view_page'
require_relative '../pages/boac/filtered_cohort_matrix_page'
require_relative '../pages/boac/student_page'
require_relative '../pages/boac/teams_list_page'
require_relative '../pages/boac/api_user_analytics_page'
require_relative '../pages/suitec/suite_c_pages'
require_relative '../pages/suitec/asset_library_page'
require_relative '../pages/suitec/engagement_index_page'
require_relative '../pages/suitec/whiteboards_page'
require_relative '../pages/suitec/impact_studio_page'
