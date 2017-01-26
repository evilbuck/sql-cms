FactoryGirl.define do

  factory :run do
    association :workflow
    association :creator, factory: :user
    execution_plan { { bogus: :plan } }
  end

  factory :run_step_log do
    association :run
    step { create(:transform, workflow: run.workflow) }
  end


end