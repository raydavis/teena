require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    test_config = BOACTestConfig.new
    test_config.search NessieUtils.get_all_students
    notes_search_word_count = BOACUtils.config['notes_search_word_count']
    dept_uids = test_config.dept_students.map &:uid

    @driver = Utils.launch_browser test_config.chrome_profile
    @homepage = BOACHomePage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @homepage.dev_auth test_config.advisor

    # COLLECT DATA TO DRIVE SEARCH TESTS

    # Get students to use for various searches
    test_students = test_config.max_cohort_members
    student_searches = []

    test_students.each do |student|

      begin
        student_search = {:student => student}

        api_student_page = BOACApiStudentPage.new @driver
        api_student_page.get_data(@driver, student)
        term = api_student_page.terms.find { |t| api_student_page.term_name(t) == BOACUtils.term }

        # Collect classes for class searches
        class_searches = []
        if term
          term_id = api_student_page.term_id term
          courses = api_student_page.courses term
          courses.each do |course|

            begin
              course_sis_data = api_student_page.sis_course_data course
              unless course_sis_data[:code].include? 'PHYS ED' # PHYS ED has too many identical-looking sections

                api_student_page.sections(course).each do |section|
                  section_data = api_student_page.sis_section_data section
                  if section_data[:primary]
                    api_section_page = BOACApiSectionPage.new @driver
                    api_section_page.get_data(@driver, term_id, section_data[:ccn])

                    class_test_case = "course #{course_sis_data[:code]} section #{section_data[:component]} #{section_data[:number]} #{section_data[:ccn]}"
                    course_code = api_section_page.course_code
                    subject_area, separator, catalog_id = course_code.rpartition(' ')
                    abbreviated_subject_area = subject_area[0..-3]
                    class_search = {
                      :test_case => class_test_case,
                      :course_code => course_code,
                      :section_number => section_data[:number],
                      :strings => [course_code, "#{abbreviated_subject_area} #{catalog_id}", catalog_id]
                    }
                    class_searches << class_search
                  end
                end
              end

            rescue => e
              Utils.log_error e
              it("hit an error collecting class search tests for UID #{student.uid} course #{course['displayName']}") { fail }
            end
          end
        else
          logger.warn "Bummer, UID #{student.uid} has no classes in the current term to search for"
        end
        student_search.merge!({:class_searches => class_searches})

        # Collect notes for note searches
        note_searches = []
        expected_asc_notes = NessieUtils.get_asc_notes student
        expected_boa_notes = BOACUtils.get_student_notes(student).delete_if &:deleted_date
        expected_sis_notes = NessieUtils.get_sis_notes student
        expected_notes = expected_sis_notes + expected_boa_notes
        expected_notes = expected_notes + expected_asc_notes if expected_asc_notes
        if expected_notes.any?
          expected_notes.each do |note|

            begin
              note_test_case = "UID #{student.uid} note ID #{note.id}"

              if note.source_body_empty || !note.body || note.body.empty?
                logger.warn "Skipping search test for #{note_test_case} because the note body was empty and too many results will be returned."

              else
                body_words = note.body.split(' ')
                body_words = (body_words.map { |w| w.split("\n") }).flatten
                search_string = body_words[0..(notes_search_word_count-1)].join(' ')
                note_search = {
                  :note => note,
                  :test_case => note_test_case,
                  :string => search_string
                }
                note_searches << note_search
              end

            rescue => e
              Utils.log_error e
              it("hit an error collecting note search tests for UID #{student.uid} note ID #{note.id}") { fail }
            end
          end
        else
          logger.warn "Bummer, UID #{student.uid} has no notes to search for"
        end
        student_search.merge!({:note_searches => note_searches})

        student_searches << student_search

      rescue => e
        Utils.log_error e
        it("hit an error collecting test searches for UID #{student.uid}") { fail }
      end
    end

    # EXECUTE SEARCHES

    @homepage.load_page

    student_searches.each do |search|

      # USER SEARCH
      begin
        @homepage.search_non_note search[:student].first_name
        complete_first_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with the complete first name") { expect(complete_first_results).to be true }

        @homepage.search_non_note search[:student].first_name[0..2]
        partial_first_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with a partial first name") { expect(partial_first_results).to be true }

        @homepage.search_non_note search[:student].last_name
        complete_last_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with the complete last name") { expect(complete_last_results).to be true }

        @homepage.search_non_note search[:student].last_name[0..2]
        partial_last_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with a partial last name") { expect(partial_last_results).to be true }

        @homepage.search_non_note "#{search[:student].first_name} #{search[:student].last_name}"
        complete_first_last_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with the complete first and last name") { expect(complete_first_last_results).to be true }

        @homepage.search_non_note "#{search[:student].last_name}, #{search[:student].first_name}"
        complete_last_first_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with the complete last and first name") { expect(complete_last_first_results).to be true }

        @homepage.search_non_note "#{search[:student].first_name[0..2]} #{search[:student].last_name[0..2]}"
        partial_first_last_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with a partial first and last name") { expect(partial_first_last_results).to be true }

        @homepage.search_non_note "#{search[:student].last_name[0..2]}, #{search[:student].first_name[0..2]}"
        partial_last_first_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with a partial last and first name") { expect(partial_last_first_results).to be true }

        @homepage.search_non_note search[:student].sis_id.to_s
        complete_sid_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with the complete SID") { expect(complete_sid_results).to be true }

        @homepage.search_non_note search[:student].sis_id.to_s[0..4]
        partial_sid_results = @search_results_page.student_in_search_result?(@driver, search[:student])
        it("finds UID #{search[:student].uid} with a partial SID") { expect(partial_sid_results).to be true }

      rescue => e
        Utils.log_error e
        it("hit an error performing user searches for UID #{search[:student].uid}") { fail }
      end

      # CLASS SEARCH

      search[:class_searches].each do |class_search|
        class_search[:strings].each do |string|

          begin
            @homepage.search_non_note string
            class_result = @search_results_page.class_in_search_result?(class_search[:course_code], class_search[:section_number])
            it("allows the user to search for #{class_search[:test_case]} by string '#{string}'") { expect(class_result).to be true }

            if @search_results_page.class_link(class_search[:course_code], class_search[:section_number]).exists?
              @search_results_page.click_class_result(class_search[:course_code], class_search[:section_number])
              class_link_works = @class_page.verify_block { @class_page.wait_for_title class_search[:course_code] }
              it("allows the user to visit the class page for #{class_search[:test_case]} from search results") { expect(class_link_works).to be true }
            end

          rescue => e
            Utils.log_error e
            it("hit an error performing a class search for #{class_search[:test_case]}") { fail }
          end
        end
      end

      # NOTE SEARCH

      search[:note_searches].each do |note_search|

        begin
          if note_search[:note].source_body_empty || !note_search[:note].body || note_search[:note].body.empty?
            logger.warn "Skipping search test for #{note_search[:test_case]} because the source note body was empty and too many results will be returned."

          else

            # Search string

            @homepage.search_note note_search[:string]

            results_count = @search_results_page.note_results_count
            it("returns results when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]}") { expect(results_count).to be > 0 }

            unless results_count.zero?
              it("shows no more than 100 results when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]}") { expect(results_count).to be <= 100 }

              @search_results_page.wait_for_note_search_result_rows
              visible_student_uids = @search_results_page.note_result_uids
              it("returns only results for students in the advisor's department when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]}") { expect(visible_student_uids - dept_uids).to be_empty }

              student_result_returned = @search_results_page.note_in_search_result?(note_search[:note])
              it("returns a result when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]}") { expect(student_result_returned).to be true }

              if student_result_returned && @search_results_page.note_results_count < 100
                result = @search_results_page.note_result(search[:student], note_search[:note])
                updated_date_expected = note_search[:note].updated_date && note_search[:note].updated_date != note_search[:note].created_date && note_search[:note].advisor.uid != 'UCBCONVERSION'
                expected_date = updated_date_expected ? note_search[:note].updated_date : note_search[:note].created_date
                expected_date_text = "#{expected_date.strftime('%b %-d, %Y')}"
                it("note search shows the student name for #{note_search[:test_case]}") { expect(result[:student_name]).to eql(search[:student].full_name) }
                it("note search shows the student SID for #{note_search[:test_case]}") { expect(result[:student_sid]).to eql(search[:student].sis_id) }
                it("note search shows a snippet of #{note_search[:test_case]}") { expect(result[:snippet].gsub(/\W/, '')).to include(note_search[:string].gsub(/\W/, '')) }
                # TODO it("note search shows the advisor name on #{note_search[:test_case]}") { expect(result[:advisor_name]).not_to be_nil } unless note.advisor_uid == 'UCBCONVERSION'
                it("note search shows the most recent updated date on #{note_search[:test_case]}") { expect(result[:date]).to eql(expected_date_text) }
              end
            end

            # Topics

            @homepage.expand_search_options_notes_subpanel
            note_topics = note_search[:note].topics & Topic::TOPICS.map(&:name)

            note_topics.each do |note_topic|

              topic = Topic::TOPICS.find(&:name) == note_topic
              @homepage.select_note_topic topic
              @homepage.search_note note_search[:string]
              topic_match = @search_results_page.note_in_search_result?(note_search[:note])
              it("returns a result when searching with the first #{notes_search_word_count} words in note ID #{note_search[:note].id} and matching topic #{topic.name}") do
                expect(topic_match).to be true
              end

              non_topic = Topic::TOPICS.find(&:name) != note_topic
              @homepage.select_note_topic non_topic
              @homepage.search_note note_search[:string]
              topic_no_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns no result when searching with the first #{notes_search_word_count} words in note ID #{note_search[:note].id} and non-matching topic #{topic.name}" do
                expect(topic_no_match).to be false
              end
            end

            # Posted by

            logger.info "Checking filters for #{note_search[:test_case]} posted by UID #{note_search[:note].advisor.uid}"

            if note_search[:note].advisor.uid == test_config.advisor.uid
              logger.info 'Searching for a note posted by the logged in advisor'

              # Posted by you
              @homepage.select_notes_posted_by_you
              @homepage.search_note note_search[:string]
              you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns a result when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                expect(you_posted_match).to be true
              end

              # Posted by anyone
              @homepage.select_notes_posted_by_anyone
              @homepage.search_note note_search[:string]
              anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns a result when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]} and posted by anyone" do
                expect(anyone_posted_match).to be true
              end

            else
              logger.info 'Searching for a note posted by someone other than the logged in advisor'

              # Posted by you
              @homepage.select_notes_posted_by_you
              @homepage.search_note note_search[:string]
              if @search_results_page.note_results_count == 20
                logger.warn "Skipping a test with note ID #{note_search[:note].id} because there are more than 20 results"
              else
                you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns no result when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                  expect(you_posted_match).to be_falsey
                end
              end

              # Posted by anyone
              @homepage.select_notes_posted_by_anyone
              @homepage.search_note note_search[:string]
              anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns a result when searching with the first #{notes_search_word_count} words in #{note_search[:test_case]} and posted by anyone" do
                expect(anyone_posted_match).to be true
              end
            end
          end

        rescue => e
          Utils.log_error e
          it("hit an error executing a note search test for #{note_search[:test_case]}") { fail }
        end
      end
    end

  rescue => e
    Utils.log_error e
    it('test hit an error initializing') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
