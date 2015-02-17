class ResetDiscussionReaderCounts < ActiveRecord::Migration
  def create_progress_bar(total)
    ProgressBar.create(format: "(\e[32m%c/%C\e[0m) %a |%B| \e[31m%e\e[0m ",
                       progress_mark: "\e[32m/\e[0m",
                       total: total)
  end
  def change
    bar = create_progress_bar(DiscussionReader.count)
    Discussion.pluck(:id).each do |discussion_id|
      bar.increment
      DiscussionReader.where(discussion_id: discussion_id).find_each do |dr|
        dr.reset_counts!
      end
    end
  end
end
