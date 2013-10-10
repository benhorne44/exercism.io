require 'digest/sha1'

class User < ActiveRecord::Base

  include Locksmith
  include ProblemSet

=begin
  include Mongoid::Document

  field :u, as: :username, type: String
  field :email, type: String
  field :img, as: :avatar_url, type: String
  field :g_id, as: :github_id, type: Integer
  field :key, type: String, default: ->{ create_key }
  field :j_at, type: Time, default: ->{ Time.now.utc }

  field :ms, as: :mastery, type: Array, default: []
  field :cur, as: :current, type: Hash, default: {}
  field :comp, as: :completed, type: Hash, default: {}

  has_many :submissions
  has_many :notifications
  has_many :comments
  has_and_belongs_to_many :teams, inverse_of: :member
  has_many :teams_created, class_name: "Team", inverse_of: :creator
=end

  serialize :mastery, Array
  serialize :current, Hash
  serialize :completed, Hash

  has_many :submissions
  has_many :notifications
  has_many :comments

  has_many :teams_created, class_name: "Team", foreign_key: :creator_id
  has_many :team_memberships, class_name: "TeamMembership"
  has_many :teams, through: :team_memberships

  def self.from_github(id, username, email, avatar_url)
    user = User.where(github_id: id).first ||
           User.new(github_id: id, email: email)

    user.username   = username
    user.avatar_url = avatar_url.gsub(/\?.+$/, '') if avatar_url && !user.avatar_url
    user.save
    user
  end

  def self.find_in_usernames(usernames)
    User.where(username: usernames.map {|u| /\A#{u}\z/i})
  end

  def self.find_by_username(username)
    where(username: /\A#{username}\z/i).first
  end

  def random_work
    completed.keys.shuffle.each do |language|
      exercise = completed_exercises[language].sample
      work = Submission.pending_for(language, exercise.slug).unmuted_for(username).asc(:nit_count)
      if work.count > 0
        return work.limit(10).to_a.sample
      end
    end
    nil
  end

  def ongoing
    @ongoing ||= Submission.pending.where(user_id: id)
  end

  def done
    @done ||= completed_exercises.map do |lang, exercises|
      exercises.map { |exercise|
        latest_submission_on(exercise)
      }
    end.flatten
  end

  def submissions_on(exercise)
    submissions.order(at: :desc).where(language: exercise.language, slug: exercise.slug)
  end

  def most_recent_submission
    submissions.order(at: :asc).last
  end

  def guest?
    false
  end

  def do!(exercise)
    self.current[exercise.language] = exercise.slug
    save
  end

  def sees?(language)
    doing?(language) || did?(language) || locksmith_in?(language)
  end

  def complete!(exercise)
    self.completed[exercise.language] ||= []
    self.completed[exercise.language] << exercise.slug
    self.current.delete(exercise.language)
    save
  end

  def nitpicks_trail?(language)
    (completed.keys + current.keys).include?(language) || locksmith_in?(language)
  end

  def current_exercises
    current.to_a.map {|cur| Exercise.new(*cur)}
  end

  def ==(other)
    username == other.username && current == other.current
  end

  def is?(handle)
    username == handle
  end

  def nitpicker_on?(exercise)
    locksmith_in?(exercise.language) || completed?(exercise)
  end

  def nitpicker?
    locksmith? || completed.size > 0
  end

  def new?
    !locksmith? && submissions.count == 0
  end

  def owns?(submission)
    self == submission.user
  end

  def stashed_submissions
    self.submissions.select{ |submission| submission.stashed? }
  end

  def stash_list
    self.stashed_submissions.map(&:stash_name)
  end

  def clear_stash(filename)
    self.stashed_submissions.each do |sub|
      sub.delete if sub.stash_name == filename
    end
  end

  def latest_submission
    @latest_submission ||= submissions.pending.order(at: :desc).first
  end

  private

  def latest_submission_on(exercise)
    submissions_on(exercise).first
  end

  def create_key
    Digest::SHA1.hexdigest(secret)
  end

  def secret
    if ENV['USER_API_KEY']
      "#{ENV['USER_API_KEY']} #{github_id}"
    else
      "There is solemn satisfaction in doing the best you can for #{github_id} billion people."
    end
  end
end

