class ChatsController < ApplicationController
  include ActionController::Live

  @@history = [{ role: "system", content: "You are a helpful sales assistant. In order to help customers to find the right offering he want, we need to know a few things from customers.
1. we need to know the customers want to ship the product from which port( this would be origin port) to which port (this would be destination port)
2. we need to know when the cargo ready -- this would be cargo ready date
3. we need to know the cargo weight and volume
Once you have all the information (origin port, destination port, cargo ready date, cargo weight, cargo volume) you can tell the users wait a second and we would contact them later." }]

  def show
    response.headers['Content-Type']  = 'text/event-stream'
    response.headers['Last-Modified'] = Time.now.httpdate
    sse                               = SSE.new(response.stream, event: "message")
    client                            = OpenAI::Client.new(access_token: ENV["OPENAI_ACCESS_TOKEN"])
    full_responses = ""
    begin
      client.chat(
        parameters: {
          model:    "gpt-4o",
          messages: @@history.push({ role: "user", content: params[:prompt] }),
          stream: proc do |chunk|
            content = chunk.dig("choices", 0, "delta", "content")
            if content.nil?
              @@history.push({ role: "assistant", content: full_responses})
              Rails.logger.info(@@history)
              return
            end
            full_responses += content
            sse.write({
              message: content,
            })
          end
        }
      )
    ensure
      sse.close
    end
  end
end
