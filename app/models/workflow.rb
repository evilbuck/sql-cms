# == Schema Information
#
# Table name: workflows
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  slug       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  params     :jsonb
#
# Indexes
#
#  index_workflows_on_lowercase_name  (lower((name)::text)) UNIQUE
#  index_workflows_on_lowercase_slug  (lower((slug)::text)) UNIQUE
#

class Workflow < ApplicationRecord

  # This class represents a particular configuration of an SQL Workflow at a particular point in time.
  # Its name and slug are case-insensitively unique, here and in the DB.

  include Concerns::SqlHelpers

  include Concerns::SqlSlugs

  include Concerns::ParamsHelpers

  auto_normalize

  # Validations

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  validates :slug, presence: true, uniqueness: { case_sensitive: false }

  validate :slug_valid_sql_identifier

  def slug_valid_sql_identifier
    errors.add(:slug, "Is not a valid SQL identifier") unless slug =~ /^[a-z_]([a-z0-9_])*$/
  end

  # NB - example TSV import: %q{COPY :table_name FROM STDIN WITH DELIMITER E'\t' NULL ''}

  # Callbacks

  before_destroy :raise_if_depended_upon

  private def raise_if_depended_upon
    raise "You cannot destroy this Workflow because other Workflows still depend upon it." if including_dependencies.exists?
  end

  # Associations

  has_many :transforms, inverse_of: :workflow, dependent: :destroy

  has_many :workflow_data_quality_reports, inverse_of: :workflow, dependent: :delete_all
  has_many :data_quality_reports, through: :workflow_data_quality_reports

  has_many :included_dependencies, class_name: 'WorkflowDependency', foreign_key: :including_workflow_id, dependent: :delete_all
  has_many :included_workflows, through: :included_dependencies, source: :included_workflow

  has_many :including_dependencies, class_name: 'WorkflowDependency', foreign_key: :included_workflow_id, dependent: :delete_all
  has_many :including_workflows, through: :including_dependencies, source: :including_workflow

  has_many :workflow_configurations, inverse_of: :workflow, dependent: :delete_all

  has_many :runs, through: :workflow_configurations

  # Scopes



  # Instance Methods

  def to_s
    slug
  end

  # FIXME - Copy/paste from Transform model; DRY up sometime
  concerning :EligibleIncludedWorkflows do

    included do
      accepts_nested_attributes_for :included_workflows
    end

    # Any Workflow that doesn't directly or indirectly have this Workflow already included is itself available as an includable workflow (and may already be such).
    # This is how we avoid cycles in the Workflow Dependency graph.
    # There has to be an algorithmic way to obtain the "Sibling groups" of a DAG starting from the leaf nodes and going up, as this does ... but couldn't find it
    def available_included_workflows
      base_arel = Workflow.order(:name)
      if new_record?
        base_arel.all
      else
        eligible_workflow_ids = base_arel.where("id <> #{id}").pluck(:id)
        Workflow.where(id: eligible_workflow_ids.reject { |eligible_workflow_id| already_including_me?(eligible_workflow_id) }).sort_by { |w| w.name.downcase }
      end
    end

    private

    def already_including_me?(workflow_id)
      dependent_ids = WorkflowDependency.where(including_workflow_id: workflow_id).pluck(:included_workflow_id)
      return false if dependent_ids.empty?
      return true if dependent_ids.include?(id)
      dependent_ids.any? { |dependent_id| already_including_me?(dependent_id) }
    end

  end

  # Yeah, I could have done this via https://ruby-doc.org/stdlib-2.4.1/libdoc/tsort/rdoc/TSort.html
  # But, it's so much more satisfying to figure it out all by myself ...
  concerning :TransformTopologicalSort do

    def ordered_transform_groups
      unused_transform_ids = transforms.map(&:id)
      return [] if unused_transform_ids.empty?

      groups_arr = []

      independent_transforms = transforms.independent.to_a

      # NB: This can also happen if a Transform Dependency is hooked-up to a Transform from another Workflow,
      #      which is why we haven't yet sorted out moving Transforms between Workflows
      raise "Your alleged DAG is a cyclical graph because it has no leaf nodes." if independent_transforms.empty?

      groups_arr << independent_transforms
      unused_transform_ids -= independent_transforms.map(&:id)

      # Ah, my old nemesis, the while loop, ever insidiously scheming to iterate indefinitely.
      while unused_transform_ids.present?
        next_group = next_transform_group(transform_groups_thus_far: groups_arr, unused_transform_ids: unused_transform_ids)
        # NB: This can also happen if a Transform Dependency is hooked-up to a Transform from another Workflow,
        #      which is why we haven't yet sorted out moving Transforms between Workflows
        raise "Your alleged DAG is a cyclical graph because no transform group may be formed from the remaining transforms." if next_group.empty?
        groups_arr << next_group
        unused_transform_ids -= next_group.map(&:id)
      end

      groups_arr.map { |arr| Set.new(arr) }
    end

    private def next_transform_group(transform_groups_thus_far:, unused_transform_ids:)
      used_transform_ids = transform_groups_thus_far.flatten.map(&:id)
      joined_used_transform_ids = used_transform_ids.join(',')
      transforms.
        where(id: unused_transform_ids).
        where("NOT EXISTS (SELECT 1 FROM transform_dependencies WHERE prerequisite_transform_id NOT IN (?) AND postrequisite_transform_id = transforms.id)", used_transform_ids).
        to_a
    end

  end


end
