
class ChargesController < ApplicationController
  class InvalidLineItem < StandardError; end

  # POST /charges
  def create
    # TODO(jtmckibb): This is a secret, shhhh
    Stripe.api_key = 'sk_test_Vux9P2VnjEDHuR4Cg8DHWmhq00y6iKGY8x'

    begin
      merchant_id = charge_params[:merchant_id]
      line_items = charge_params[:line_items].map(&:to_h)

      line_items.each { |item| validate(line_item: item) }

      session = Stripe::Checkout::Session.create(
        payment_method_types: ['card'],
        line_items: line_items,
        payment_intent_data: {
          capture_method: 'manual',
        },
        success_url: "https://sendchinatownlove.com/#{merchant_id}/thank-you?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "https://sendchinatownlove.com/#{merchant_id}/canceled",
        metadata: { merchant_id: merchant_id }
      )
      json_response(session)
    rescue Stripe::StripeError => e
      json_response(e.error.message, e.http_status)
    rescue ActionController::ParameterMissing, InvalidLineItem => e
      json_response(e.message, :unprocessable_entity)
    rescue InvalidLineItem => e
      json_response(e.message, :unprocessable_entity)
    rescue => e
      json_response(e, :internal_server_error)
    end
  end

  private

  def charge_params
    params.require(:merchant_id)
    params.require(:line_items)
    params.permit(:merchant_id, line_items: [[:amount, :currency, :name, :quantity, :description]])
  end

  def validate(line_item:)
    [:amount, :currency, :name, :quantity].each do |attribute|
      unless line_item.key?(attribute)
        raise ActionController::ParameterMissing.new "param is missing or the value is empty: #{attribute}"
      end
    end

    unless ['Gift Card', 'Donation'].include? line_item['name']
      raise InvalidLineItem.new "line_item must be named `Gift Card` or `Donation`"
    end

    convertable_to_int = line_item['amount'] == line_item['amount'].to_i.to_s
    unless line_item['amount'].is_a? Integer || convertable_to_int
      raise InvalidLineItem.new 'line_item.amount must be an Integer'
    end

    amount = line_item['amount'].to_i
    raise InvalidLineItem.new 'Amount must be at least $0.50 usd' unless amount >= 50
  end
end