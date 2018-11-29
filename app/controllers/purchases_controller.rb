class PurchasesController < ApplicationController
#  before_action :authenticate_user!, only: [:new ]
  # GET /purchases.json
  def index
    @purchases = Purchase.all
    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @purchases }
    end
  end
  # GET /purchases/1
  def show
    @purchase = Purchase.find(params[:id])
    loot = Merchandise.find(@purchase.merchandise_id) 
    @itemname = loot.name
    id = loot.user_id
    @user = User.find(id)
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @purchase }
    end
  end
  # GET /purchases/new
  def new
    if(params[:pricesold].present?)
      # Still need to create a purchase with the price and seller parameters 
      @purchase = Purchase.new
      @purchase.pricesold = params[:pricesold]
      @purchase.author_id = params[:author_id]
      @purchase.save!
    else
      @merchandise = Merchandise.find(params[:merchandise_id])
      @purchase = @merchandise.purchases.new
    end
    
    if user_signed_in?
      if current_user.stripe_customer_token.present?
        customer = Stripe::Customer.retrieve(current_user.stripe_customer_token)
        sourceid = customer.default_source
        card = customer.sources.retrieve(sourceid)
        @last4 = card.last4
        @expmonth = card.exp_month
        @expyear = card.exp_year
      end
    end
  end
  # GET /purchases/1/edit 
  def edit
    @purchase = Purchase.find(params[:id])
  end
  # POST /purchases 
  def create
    @purchase = Purchase.new(purchase_params)

    if @purchase.book_id? # This logic is necessary for purchasing downloads. Will need to be changed for each merchandise filetypes
      @book = Book.find(@purchase.book_id) 
#    raise params.to_yaml
      @purchase.user_id = current_user.id
      if @purchase.save_with_payment
        if @purchase.bookfiletype == "pdf" && @book.bookpdf.present?
          if Rails.env.development? || Rails.env.test?
            data = open(Rails.root + "public#{@book.bookpdf.to_s}") 
            send_data data.read, filename: @book.bookpdf, type: "application/pdf", disposition: 'attachment' 
          else
            data = open("https://authorprofile.s3.amazonaws.com#{@book.bookpdf.to_s}") 
            send_data data.read, filename: @book.bookpdf, type: "application/pdf", disposition: 'attachment' 
          end
        end
        if @purchase.bookfiletype == "mobi" && @book.bookmobi.present?
          data = open("https://authorprofile.s3.amazonaws.com#{@book.bookmobi.to_s}") 
          send_data data.read, filename: @book.bookmobi, type: "application/mobi", disposition: 'attachment', stream: 'true', buffer_size: '4096' 
        end
        if @purchase.bookfiletype == "epub" && @book.bookepub.present?
          data = open("https://authorprofile.s3.amazonaws.com#{@book.bookepub.to_s}") 
          send_data data.read, filename: @book.bookepub, type: "application/epub", disposition: 'attachment', stream: 'true', buffer_size: '4096' 
        end
      else
        redirect_back fallback_location: request.referrer, :notice => "Your order did not go through. Try again."
      end
    elsif @purchase.merchandise_id?
      @merchandise = Merchandise.find(@purchase.merchandise_id)
      seller = User.find(@merchandise.user_id)
      if user_signed_in?
        @purchase.user_id = current_user.id
      end 
      if @purchase.save_with_payment
        redirect_to merchandise_path(@merchandise.id), :notice => "You successfully purchased this item. Thank you for being a patron of " + seller.name 
      else
        redirect_back fallback_location: request.referrer, :notice => "Your order did not go through. Try again."
      end
    else
      if user_signed_in?
        @purchase.user_id = current_user.id
      end
      if @purchase.save_with_payment
        redirect_to merchandise_path(@merchandise.id), :notice => "You successfully purchased this item. Thank you for being a patron of " + seller.name 
      else
        redirect_back fallback_location: request.referrer, :notice => "Your order did not go through. Try again."
      end
    end
  end

  def update #is this ever used
    @purchase = Purchase.find(params[:id])

    respond_to do |format|
      if @purchase.update_attributes(purchase_params)
        format.html { redirect_to @purchase }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @purchase.errors, status: :unprocessable_entity }
      end
    end
  end
  # DELETE /purchases/1.json
  def destroy
    @purchase = Purchase.find(params[:id])
    @purchase.destroy

    respond_to do |format|
      format.html { redirect_to purchases_url }
      format.json { head :ok }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.

    def purchase_params
      params.require(:purchase).permit( :stripe_customer_token, :bookfiletype, :groupcut, :shipaddress,
        :book_id, :stripe_card_token, :user_id, :author_id, :merchandise_id, :group_id, :email)
    end

end
