require 'spec_helper'

feature "deals feature", :js => true do
  background do
    # creates a default shipping method which is required for checkout
    Factory(:bogus_payment_method, :environment => 'test')
    # creates a check payment method so we don't need to worry about cc details
    Factory(:payment_method)

    Factory(:shipping_method, :zone => Spree::Zone.find_by_name('North America'))
    user = Factory(:admin_user)
    @mug = Factory(:product, :name => "RoR Mug", :price => "40")
    @bag = Factory(:product, :name => "RoR Bag", :price => "20")
    sign_in_as!(user)

    visit spree.new_admin_deal_path
    fill_in "Name", :with => "Ror Mug Hot deal !"
    fill_in "Starts at", :with => Date.yesterday.to_s
    fill_in "Expires at", :with => 1.week.from_now.to_s

    fill_in "Description", :with => "This is your last chance to get it at this price !"
    fill_in "Minimum Quantity", :with => 200

    page.execute_script %Q{$('input[name$="deal[product_id]"]').val('#{@mug.id}').focus();}

    click_button "Create"
    page.should have_content('Deal "Ror Mug Hot deal !" has been successfully created!')
    click_link "Edit"
    fill_in "List Price", :with => "40"
    fill_in "Price", :with => "10"
    click_button "Update"
  end

  scenario "admin can edit deal price" do
    visit spree.admin_deals_path
    click_link "Edit"
    fill_in "List Price", :with => "40"
    fill_in "Price", :with => "30"
    click_button "Update"

    visit spree.admin_deals_path
    page.should have_content("25%")
  end

  context "when deal expires" do
    before do
      visit spree.deals_path
      click_link "Ror Mug Hot deal !"
      click_button "Add To Cart"
      complete_order

      Timecop.travel(1.week.from_now + 1.minutes)
      Delayed::Worker.new.work_off
    end

    after { Timecop.return }

    scenario "admin can confirm deal" do
      visit spree.admin_deals_path
      click_button "Confirm"
      page.should have_content("Deal successfully complete")
    end

    scenario "admin can capture payment" do
      visit spree.admin_deals_path
      click_button "Confirm"
      page.should have_content("Deal successfully complete")

      click_link "Edit"

      within "ul.sidebar[data-hook='admin_deal_tabs']" do
        click_link "Orders"
      end
      page.should have_content("$20")

      visit spree.admin_order_payments_path(Spree::Order.last)
      click_button "Capture"
    end

    scenario "shipping methods" do
      visit spree.new_admin_shipping_method_path
      save_and_open_page
    end
  end

end
