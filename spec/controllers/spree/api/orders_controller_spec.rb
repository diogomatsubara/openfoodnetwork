require 'spec_helper'
require 'spree/api/testing_support/helpers'

module Spree
  describe Spree::Api::OrdersController do
    include Spree::Api::TestingSupport::Helpers
    render_views
    context "as a normal user" do
      let!(:dist1) { FactoryGirl.create(:distributor_enterprise) }
      let!(:order1) { FactoryGirl.create(:order, state: 'complete', completed_at: Time.now, distributor: dist1, billing_address: FactoryGirl.create(:address) ) }
      let!(:order2) { FactoryGirl.create(:order, state: 'complete', completed_at: Time.now, distributor: dist1, billing_address: FactoryGirl.create(:address) ) }
      let!(:order3) { FactoryGirl.create(:order, state: 'complete', completed_at: Time.now, distributor: dist1, billing_address: FactoryGirl.create(:address) ) }
      let!(:line_item1) { FactoryGirl.create(:line_item, order: order1) }
      let!(:line_item2) { FactoryGirl.create(:line_item, order: order2) }
      let!(:line_item3) { FactoryGirl.create(:line_item, order: order2) }
      let!(:line_item4) { FactoryGirl.create(:line_item, order: order3) }
      let(:order_attributes) { [:id, :full_name, :email, :phone, :completed_at, :line_items, :distributor, :order_cycle, :number] }
      let(:line_item_attributes) { [:id, :quantity, :max_quantity, :supplier, :units_product, :units_variant] }
    
      before do
        stub_authentication!
        Spree.user_class.stub :find_by_spree_api_key => current_api_user
      end

      before :each do
        spree_get :managed, { :template => 'bulk_index', :format => :json }
      end

      it "retrieves a list of orders with appropriate attributes, including line items with appropriate attributes" do
        keys = json_response.first.keys.map{ |key| key.to_sym }
        order_attributes.all?{ |attr| keys.include? attr }.should == true
      end

      it "retrieves a list of line items with appropriate attributes" do
        li_keys = json_response.first['line_items'].first.keys.map{ |key| key.to_sym }
        line_item_attributes.all?{ |attr| li_keys.include? attr }.should == true
      end

      it "sorts orders in ascending id order" do
        ids = json_response.map{ |order| order['id'] }
        ids[0].should < ids[1]
        ids[1].should < ids[2]
      end

      it "formats completed_at to 'yyyy-mm-dd hh:mm'" do
        json_response.map{ |order| order['completed_at'] }.all?{ |a| a.match("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$") }.should == true
      end

      it "returns an array for line_items" do
        json_response.map{ |order| order['line_items'] }.all?{ |a| a.is_a? Array }.should == true
      end

      it "returns quantity and max quantity at integers" do
        json_response.map{ |order| order['line_items'] }.flatten.map{ |li| li['quantity'] }.all?{ |q| q.is_a? Fixnum }.should == true
        json_response.map{ |order| order['line_items'] }.flatten.map{ |li| li['max_quantity'] }.all?{ |mq| mq.nil? || mq.is_a?( Fixnum ) }.should == true
      end

      it "returns supplier object with id and name keys" do
        json_response.map{ |order| order['line_items'] }.flatten.map{ |li| li['supplier'] }.all?{ |s| s.has_key?('id') && s.has_key?('name') }.should == true
      end

      it "returns distributor object with id and name keys" do
        json_response.map{ |order| order['distributor'] }.all?{ |d| d.has_key?('id') && d.has_key?('name') }.should == true
      end

      it "retrieves the order number" do
        json_response.map{ |order| order['number'] }.all?{ |number| number.match("^R\\d{5,10}$") }.should == true
      end
    end

    context "As a supplier enterprise user" do
      let(:supplier) { create(:supplier_enterprise) }
      let!(:order1) { FactoryGirl.create(:order, state: 'complete', completed_at: Time.now, billing_address: FactoryGirl.create(:address) ) }
      let!(:line_item1) { FactoryGirl.create(:line_item, order: order1, product: FactoryGirl.create(:product, supplier: supplier)) }
      let!(:line_item2) { FactoryGirl.create(:line_item, order: order1, product: FactoryGirl.create(:product, supplier: FactoryGirl.create(:supplier_enterprise))) }
      let(:enterprise_user) do
        user = create(:user)
        user.enterprise_roles.create(enterprise: supplier)
        user.spree_roles = []
        user.save!
        user
      end

      before :each do
        stub_authentication!
        Spree.user_class.stub :find_by_spree_api_key => enterprise_user
        spree_get :managed, { :template => 'bulk_index', :format => :json }
      end

      it "returns a list of orders with only managed line items shown" do
        json_response.map{ |order| order['line_items'] }.flatten.length.should == 1
        json_response[0]['line_items'][0]['id'].should == line_item1.id
      end
    end
  end
end