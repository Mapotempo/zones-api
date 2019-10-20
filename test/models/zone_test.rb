require 'test_helper'

class ZoneTest < ActiveSupport::TestCase
  test 'Read all features' do
    assert_not Zone.all.empty?
  end

  test 'Read ancestor' do
    one = zones(:one)
    assert one.ancestor.nil?
  end

  test 'Read children' do
    one = zones(:one)
    assert_not one.children.empty?
  end

  test 'Read recursive children' do
    one = zones(:one)
    recursive_children = Zone.recursive_children_level([one], 1)
    assert_not recursive_children.empty?
  end
end
