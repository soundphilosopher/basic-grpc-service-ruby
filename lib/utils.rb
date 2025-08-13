require "google/protobuf/timestamp_pb"

require "basic/v1/basic_services_pb"
require "basic/service/v1/service_pb"
require "io/cloudevents/v1/cloudevents_pb"

class Utils
  class Utils
    # Public: build_background_response(state:, started_at:, completed_at:, responses:) -> [Basic::Service::V1::BackgroundResponse]
    def build_background_response(state:, started_at:, completed_at:, responses:)
      payload = Basic::Service::V1::BackgroundResponseEvent.new(
        state: state,
        started_at: to_ts(started_at),
        completed_at: completed_at ? to_ts(completed_at) : nil,
        responses: responses
      )

      any = Google::Protobuf::Any.new(
        type_url: "type.googleapis.com/#{payload.class.descriptor.name}",
        value: Basic::Service::V1::BackgroundResponseEvent.encode(payload)
      )

      ce = Io::CloudEvents::V1::Proto::CloudEvent.new(
        id: SecureRandom.uuid,
        source: "urn:service:basic",
        spec_version: "1.0",
        type: payload.class.descriptor.name,
        attributes: {
          "time" => Io::CloudEvents::V1::Proto::CloudEvent::CloudEventAttributeValue.new(ce_timestamp: to_ts(Time.now))
        },
        proto_data: any
      )

      Basic::Service::V1::BackgroundResponse.new(cloud_event: ce)
    end

    # Public: fake_service_response(id, phase:) -> [Basic::Service::V1::SomeServiceResponse]
    def fake_service_response(name, protocol:)
      # process
      sleep(rand(1.0..3.0))

      Basic::Service::V1::SomeServiceResponse.new(
        id: SecureRandom.uuid,
        name: name,
        version: "v1",
        data: Basic::Service::V1::SomeServiceData.new(
          value: protocol.to_s,
          type: "protocol"
        )
      )
    end

    def to_ts(time)
      Google::Protobuf::Timestamp.new(
        seconds: time.to_i,
        nanos: time.nsec
      )
    end
  end

  # talk.rb
  class Talk
    ReplyResult = Struct.new(:text, :goodbye)

    def initialize(rng: Random.new)
      @rng = rng
    end

    # Public: reply(input) -> [text, goodbye?]
    def reply(input)
      norm = preprocess(input)
      if GOODBYE_INPUT_SET.include?(norm)
        return [sample(GOODBYE_RESPONSES), true]
      end
      [lookup_response(norm), false]
    end

    # Public: get_intro_responses(name) -> [strings]
    def get_intro_responses(name)
      intros = INTRO_RESPONSES.map { |tpl| tpl % name }
      intros << sample(FACTS)
      intros << "How are you feeling today?"
      intros
    end

    private

    def preprocess(input)
      s = input.to_s.strip.downcase
      # strip leading/trailing punctuation .,!?'"
      s.gsub(/\A[\.!?'"]+|[\.!?'"]+\z/, "")
    end

    def sample(list)
      list[@rng.rand(list.length)]
    end

    def reflect(fragment)
      fragment.split(/\s+/).map { |w| REFLECTED_WORDS[w] || w }.join(" ")
    end

    def lookup_response(input)
      REQUEST_INPUT_REGEX_TO_RESPONSE_OPTIONS.each do |re, responses|
        m = input.match(re)
        next unless m
        response = sample(responses)
        return response unless response.include?("%s")
        if m[1]
          frag = reflect(m[1])
          return response.sub("%s", frag)
        end
      end
      sample(DEFAULT_RESPONSES)
    end

    GOODBYE_INPUT_SET = Set.new(%w[bye exit goodbye quit])

    GOODBYE_RESPONSES = [
      "Goodbye. It was nice talking to you.",
      "Thank you for talking with me.",
      "Thank you, that will be $150. Have a good day!",
      "Goodbye. This was really a nice talk.",
      "Goodbye. I'm looking forward to our next session.",
      "This was a good session, wasn't it – but time is over now. Goodbye.",
      "Maybe we could discuss this over more in our next session? Goodbye.",
      "Good-bye."
    ].freeze

    REQUEST_INPUT_REGEX_TO_RESPONSE_OPTIONS = [
      [/\Ai need (.*)\z/, [
        "Why do you need %s?",
        "Would it really help you to get %s?",
        "Are you sure you need %s?"
      ]],
      [/\Awhy don'?t you ([^?]*)\??\z/, [
        "Do you really think I don't %s?",
        "Perhaps eventually I will %s.",
        "Do you really want me to %s?"
      ]],
      [/\Awhy can'?t i ([^?]*)\??\z/, [
        "Do you think you should be able to %s?",
        "If you could %s, what would you do?",
        "I don't know -- why can't you %s?",
        "Have you really tried?"
      ]],
      [/\Ai can'?t (.*)\z/, [
        "How do you know you can't %s?",
        "Perhaps you could %s if you tried.",
        "What would it take for you to %s?"
      ]],
      [/\Ai am (.*)\z/, [
        "Did you come to me because you are %s?",
        "How long have you been %s?",
        "How do you feel about being %s?"
      ]],
      [/\Ai'?m (.*)\z/, [
        "How does being %s make you feel?",
        "Do you enjoy being %s?",
        "Why do you tell me you're %s?",
        "Why do you think you're %s?"
      ]],
      [/\Aare you ([^?]*)\??\z/, [
        "Why does it matter whether I am %s?",
        "Would you prefer it if I were not %s?",
        "Perhaps you believe I am %s.",
        "I may be %s -- what do you think?"
      ]],
      [/\Awhat (.*)\z/, [
        "Why do you ask?",
        "How would an answer to that help you?",
        "What do you think?"
      ]],
      [/\Ahow (.*)\z/, [
        "How do you suppose?",
        "Perhaps you can answer your own question.",
        "What is it you're really asking?"
      ]],
      [/\Abecause (.*)\z/, [
        "Is that the real reason?",
        "What other reasons come to mind?",
        "Does that reason apply to anything else?",
        "If %s, what else must be true?"
      ]],
      [/(.*) sorry (.*)/, [
        "There are many times when no apology is needed.",
        "What feelings do you have when you apologize?"
      ]],
      [/\Ahello(.*)\z/, [
        "Hello...I'm glad you could drop by today.",
        "Hello there...how are you today?",
        "Hello, how are you feeling today?"
      ]],
      [/\Ahi(.*)\z/, [
        "Hello...I'm glad you could drop by today.",
        "Hi there...how are you today?",
        "Hello, how are you feeling today?"
      ]],
      [/\Athanks(.*)\z/, ["You're welcome!", "Anytime!"]],
      [/\Athank you(.*)\z/, ["You're welcome!", "Anytime!"]],
      [/\Agood morning(.*)\z/, [
        "Good morning...I'm glad you could drop by today.",
        "Good morning...how are you today?",
        "Good morning, how are you feeling today?"
      ]],
      [/\Agood afternoon(.*)\z/, [
        "Good afternoon...I'm glad you could drop by today.",
        "Good afternoon...how are you today?",
        "Good afternoon, how are you feeling today?"
      ]],
      [/\Ai think (.*)\z/, [
        "Do you doubt %s?",
        "Do you really think so?",
        "But you're not sure %s?"
      ]],
      [/(.*) friend (.*)/, [
        "Tell me more about your friends.",
        "When you think of a friend, what comes to mind?",
        "Why don't you tell me about a childhood friend?"
      ]],
      [/\Ayes\z/, [
        "You seem quite sure.",
        "OK, but can you elaborate a bit?"
      ]],
      [/(.*) computer(.*)/, [
        "Are you really talking about me?",
        "Does it seem strange to talk to a computer?",
        "How do computers make you feel?",
        "Do you feel threatened by computers?"
      ]],
      [/\Ais it (.*)\z/, [
        "Do you think it is %s?",
        "Perhaps it's %s -- what do you think?",
        "If it were %s, what would you do?",
        "It could well be that %s."
      ]],
      [/\Ait is (.*)\z/, [
        "You seem very certain.",
        "If I told you that it probably isn't %s, what would you feel?"
      ]],
      [/\Acan you ([^?]*)\??\z/, [
        "What makes you think I can't %s?",
        "If I could %s, then what?",
        "Why do you ask if I can %s?"
      ]],
      [/(.*)dream(.*)/, ["Tell me more about your dream."]],
      [/\Acan i ([^?]*)\??\z/, [
        "Perhaps you don't want to %s.",
        "Do you want to be able to %s?",
        "If you could %s, would you?"
      ]],
      [/\Ayou are (.*)\z/, [
        "Why do you think I am %s?",
        "Does it please you to think that I'm %s?",
        "Perhaps you would like me to be %s.",
        "Perhaps you're really talking about yourself?"
      ]],
      [/\Ayou'?re (.*)\z/, [
        "Why do you say I am %s?",
        "Why do you think I am %s?",
        "Are we talking about you, or me?"
      ]],
      [/\Ai don'?t (.*)\z/, [
        "Don't you really %s?",
        "Why don't you %s?",
        "Do you want to %s?"
      ]],
      [/\Ai feel (.*)\z/, [
        "Good, tell me more about these feelings.",
        "Do you often feel %s?",
        "When do you usually feel %s?",
        "When you feel %s, what do you do?",
        "Feeling %s? Tell me more."
      ]],
      [/\Ai have (.*)\z/, [
        "Why do you tell me that you've %s?",
        "Have you really %s?",
        "Now that you have %s, what will you do next?"
      ]],
      [/\Ai would (.*)\z/, [
        "Could you explain why you would %s?",
        "Why would you %s?",
        "Who else knows that you would %s?"
      ]],
      [/\Ais there (.*)\z/, [
        "Do you think there is %s?",
        "It's likely that there is %s.",
        "Would you like there to be %s?"
      ]],
      [/\Amy (.*)\z/, [
        "I see, your %s.",
        "Why do you say that your %s?",
        "When your %s, how do you feel?"
      ]],
      [/\Ayou (.*)\z/, [
        "We should be discussing you, not me.",
        "Why do you say that about me?",
        "Why do you care whether I %s?"
      ]],
      [/\Awhy (.*)\z/, [
        "Why don't you tell me the reason why %s?",
        "Why do you think %s?"
      ]],
      [/\Ai want (.*)\z/, [
        "What would it mean to you if you got %s?",
        "Why do you want %s?",
        "What would you do if you got %s?",
        "If you got %s, then what would you do?"
      ]],
      [/(.*) mother(.*)/, [
        "Tell me more about your mother.",
        "What was your relationship with your mother like?",
        "How do you feel about your mother?",
        "How does this relate to your feelings today?",
        "Good family relations are important."
      ]],
      [/(.*) father(.*)/, [
        "Tell me more about your father.",
        "How did your father make you feel?",
        "How do you feel about your father?",
        "Does your relationship with your father relate to your feelings today?",
        "Do you have trouble showing affection with your family?"
      ]],
      [/(.*) child(.*)/, [
        "Did you have close friends as a child?",
        "What is your favorite childhood memory?",
        "Do you remember any dreams or nightmares from childhood?",
        "Did the other children sometimes tease you?",
        "How do you think your childhood experiences relate to your feelings today?"
      ]],
      [/(.*)\?\z/, [
        "Why do you ask that?",
        "Please consider whether you can answer your own question.",
        "Perhaps the answer lies within yourself?",
        "Why don't you tell me?"
      ]]
    ].freeze

    DEFAULT_RESPONSES = [
      "Please tell me more.",
      "Let's change focus a bit...Tell me about your family.",
      "Can you elaborate on that?",
      "I see.",
      "Very interesting.",
      "I see. And what does that tell you?",
      "How does that make you feel?",
      "How do you feel when you say that?"
    ].freeze

    REFLECTED_WORDS = {
      "am" => "are",
      "was" => "were",
      "i" => "you",
      "i'd" => "you would",
      "i've" => "you have",
      "i'll" => "you will",
      "my" => "your",
      "are" => "am",
      "you've" => "I have",
      "you'll" => "I will",
      "your" => "my",
      "yours" => "mine",
      "you" => "me",
      "me" => "you"
    }.freeze

    INTRO_RESPONSES = [
      "Hi %s. I'm just a greeter.",
      "Before we begin, %s, let me tell you something about myself."
    ].freeze

    FACTS = [
      "I was created by Joseph Weizenbaum.",
      "I was created in the 1960s.",
      "I am a Rogerian psychotherapist.",
      "I am named after Eliza Doolittle from the play Pygmalion.",
      "I was originally written on an IBM 7094.",
      "I can be accessed in most Emacs implementations with the command M-x doctor.",
      "I was created at the MIT Artificial Intelligence Laboratory.",
      "I was one of the first programs capable of attempting the Turing test.",
      "I was designed as a method to show the superficiality of communication between man and machine."
    ].freeze
  end
end
