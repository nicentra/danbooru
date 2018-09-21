class DmailFilter < ApplicationRecord
  belongs_to :user
  validates_presence_of :user
  before_validation :initialize_user

  def initialize_user
    unless user_id
      self.user_id = CurrentUser.user.id
    end
  end

  def filtered?(dmail)
    dmail.from.level < User::Levels::MODERATOR && has_filter? && (dmail.body =~ regexp || dmail.title =~ regexp || dmail.from.name =~ regexp)
  end

  def has_filter?
    !words.strip.empty?
  end

  def regexp
    @regexp ||= /\b#{Regexp.union(words.split(/[[:space:]]+/))}\b/
  end
end
