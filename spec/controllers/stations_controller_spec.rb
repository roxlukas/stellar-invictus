require 'rails_helper'

RSpec.describe StationsController, type: :controller do
  context 'without login' do
    describe 'GET index' do
      it 'should redirect when user not logged in' do
        get :index
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    describe 'POST dock' do
      it 'should redirect when user not logged in' do
        post :dock
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    describe 'POST undock' do
      it 'should redirect when user not logged in' do
        post :undock
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    describe 'POST buy' do
      it 'should redirect when user is not logged in' do
        post :buy
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    describe 'POST store' do
      it 'should redirect when user is not logged in' do
        post :store
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    describe 'POST load' do
      it 'should redirect when user is not logged in' do
        post :load
        expect(response.code).to eq('302')
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
  
  context 'with login' do
    before(:each) do
      @user = FactoryBot.create(:user_with_faction)
      sign_in @user
    end
    
    describe 'GET index' do
      it 'should display index when user is docked' do
        @user.update_columns(docked: true)
        get :index
        expect(response.code).to eq('200')
      end
      
      it 'should redirect_to game when user is not docked' do
        get :index
        expect(response.code).to eq('302')
        expect(response).to redirect_to(game_path)
      end
    end
    
    describe 'POST dock' do
      it 'should set user to docked if at station' do
        @user.update_columns(location_id: Location.where(location_type: 'station').first.id)
        post :dock
        expect(response.code).to eq('204')
        expect(@user.reload.docked).to be_truthy
      end
      
      it 'should do nothing when user not at station' do
        post :dock
        expect(response.code).to eq('204')
        expect(@user.docked).to be_falsey
      end
      
      it 'should remove user as target of other users' do
        user2 = FactoryBot.create(:user_with_faction)
        user2.update_columns(target_id: @user.id)
        
        expect(user2.target_id).to eq(@user.id)
        post :dock
        expect(response.code).to eq('204')
        expect(@user.reload.docked).to be_truthy
        expect(user2.reload.target_id).to eq(nil)
      end
    end
    
    describe 'POST undock' do
      it 'should set user to docked false if at station and docked' do
        @user.update_columns(location_id: Location.where(location_type: 'station').first.id, docked: true)
        post :undock
        expect(response.code).to eq('204')
        expect(@user.docked).to eq(true)
      end
      
      it 'should do nothing when user is not docked' do
        post :undock
        expect(response.code).to eq('204')
        expect(@user.docked).to eq(false)
      end
    end
    
    describe 'POST buy' do
      it 'should respond with 400 if no ship given' do
        post :buy
        expect(response.code).to eq('204')
      end
      
      it 'should respond with 400 if wrong ship given' do
        post :buy, params: {type: 'ship', name: 'Noot'}
        expect(response.code).to eq('204')
      end
      
      it 'should respond with flash if not enough units' do
        post :buy, params: {type: 'ship', name: 'Chronos'}
        expect(response.code).to eq('204')
        expect(flash[:alert]).to be_present
      end
      
      it 'should create new ship and remove from units if ok' do
        @user.update_columns(units: 50000)
        
        post :buy, params: {type: 'ship', name: 'Chronos'}
        expect(response.code).to eq('204')
        expect(flash[:notice]).to be_present
        expect(@user.reload.units).to eq(45000)
        expect(Spaceship.count).to eq(2)
        expect(Spaceship.last.get_attribute('storage')).to eq(80)
      end
    end
    
    describe 'POST store' do
      before(:each) do
        @user.update_columns(location_id: Location.where(location_type: 'station').first.id, docked: true)
        3.times do
          Item.create(loader: 'test', spaceship: @user.active_spaceship)
        end
      end
      
      it 'should store items in station' do
        expect(@user.active_spaceship.get_weight).to eq(3)
        post :store, params: {loader: 'test', amount: 3}
        expect(response.code).to eq('200')
        expect(@user.active_spaceship.get_weight).to eq(0)
        expect(@user.location.items.count).to eq(3)
      end
      
      it 'should not store more items in station than player has' do
        expect(@user.active_spaceship.get_weight).to eq(3)
        post :store, params: {loader: 'test', amount: 4}
        expect(response.code).to eq('400')
        expect(@user.active_spaceship.get_weight).to eq(3)
        expect(@user.location.items.count).to eq(0)
      end
      
      it 'should not store less items in station than 0' do
        expect(@user.active_spaceship.get_weight).to eq(3)
        post :store, params: {loader: 'test', amount: -1}
        expect(response.code).to eq('400')
        expect(@user.active_spaceship.get_weight).to eq(3)
        expect(@user.location.items.count).to eq(0)
      end
    end
    
    describe 'POST load' do
      before(:each) do
        @user.update_columns(location_id: Location.where(location_type: 'station').first.id, docked: true)
        3.times do
          Item.create(loader: 'test', user: @user, location: @user.location)
        end
      end
      
      it 'should store items in ship' do
        expect(@user.location.items.count).to eq(3)
        post :load, params: {loader: 'test', amount: 3}
        expect(response.code).to eq('200')
        expect(@user.active_spaceship.get_weight).to eq(3)
        expect(@user.location.items.count).to eq(0)
      end
      
      it 'should not store more items in ship than player has' do
        expect(@user.location.items.count).to eq(3)
        post :load, params: {loader: 'test', amount: 4}
        expect(response.code).to eq('400')
        expect(@user.active_spaceship.get_weight).to eq(0)
        expect(@user.location.items.count).to eq(3)
      end
      
      it 'should not store less items in ship than 0' do
        expect(@user.location.items.count).to eq(3)
        post :load, params: {loader: 'test', amount: -1}
        expect(response.code).to eq('400')
        expect(@user.active_spaceship.get_weight).to eq(0)
        expect(@user.location.items.count).to eq(3)
      end
      
      it 'should not store more items in ship than ship can carry' do
        10.times do
          Item.create(loader: 'test', user: @user, location: @user.location)
        end
        expect(@user.location.items.count).to eq(13)
        post :load, params: {loader: 'test', amount: 13}
        expect(response.code).to eq('400')
        expect(@user.active_spaceship.get_weight).to eq(0)
        expect(@user.location.items.count).to eq(13)
      end
    end
  end
end