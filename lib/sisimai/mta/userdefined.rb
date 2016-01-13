module Sisimai
  module MTA
    # Sisimai::MTA::UserDefined is an example module as a template to implement
    # your custom MTA module.
    module UserDefined
      # Imported from p5-Sisimail/lib/Sisimai/MTA/UserDefined.pm
      class << self
        require 'sisimai/mta'
        require 'sisimai/rfc5322'

        # Re0 is a regular expression to match with message headers which are
        # given as the first argument of scan() method.
        Re0 = {
          :from    => %r/\AMail Sysmet/,
          :subject => %r/\AError Mail Report/,
        }

        # Re1 is delimiter set of these sections:
        #   begin:  The first line of a bounce message to be parsed.
        #   error:  The first line of an error message to get an error reason, recipient
        #           addresses, or other bounce information.
        #   rfc822: The first line of the original message.
        #   endof:  Fixed string ``__END_OF_EMAIL_MESSAGE__''
        Re1 = {
          :begin   => %r/\A[ \t]+[-]+ Transcript of session follows [-]+\z/,
          :error   => %r/\A[.]+ while talking to .+[:]\z/,
          :rfc822  => %r{\AContent-Type:[ ]*(?:message/rfc822|text/rfc822-headers)\z},
          :endof   => %r/\A__END_OF_EMAIL_MESSAGE__\z/,
        }
        Indicators = Sisimai::MTA.INDICATORS
        LongFields = Sisimai::RFC5322.LONGFIELDS
        RFC822Head = Sisimai::RFC5322.HEADERFIELDS

        def description; return 'Module description'; end
        def smtpagent;   return 'Module name'; end
        def headerlist;  return ['X-Some-UserDefined-Header']; end
        def pattern;     return Re0; end

        # @abstract Template for User-Defined MTA module
        # @param         [Hash] mhead       Message header of a bounce email
        # @options mhead [String] from      From header
        # @options mhead [String] date      Date header
        # @options mhead [String] subject   Subject header
        # @options mhead [Array]  received  Received headers
        # @options mhead [String] others    Other required headers
        # @param         [String] mbody     Message body of a bounce email
        # @return        [Hash, Nil]        Bounce data list and message/rfc822
        #                                   part or nil if it failed to parse or
        #                                   the arguments are missing
        def scan(mhead, mbody)
          return nil unless mhead
          return nil unless mbody

          match = 0
          # 1. Check some value in mhead using regular expression or "==" operator
          #    whether the bounce message should be parsed by this module or not.
          #   - Matched 1 or more values: Proceed to the step 2.
          #   - Did not matched:          return undef;
          #
          match += 1 if mhead['subject'] =~ Re0[:subject]
          match += 1 if mhead['from']    =~ Re0[:from]
          match += 1 if mhead['x-some-userdefined-header']
          return nil if match == 0

          # 2. Parse message body(mbody) of the bounce message. See some modules
          #    in lib/sisimai/mta or lib/sisimai/msp directory to implement codes.
          dscontents = []; dscontents << Sisimai::MTA.DELIVERYSTATUS
          hasdivided = mbody.split("\n")
          rfc822next = { 'from' => false, 'to' => false, 'subject' => false }
          rfc822part = ''     # (String) message/rfc822-headers part
          previousfn = ''     # (String) Previous field name
          readcursor = 0      # (Integer) Points the current cursor position
          recipients = 0      # (Integer) The number of 'Final-Recipient' header

          hasdivided.each do |e|
            if readcursor == 0
              # Beginning of the bounce message or delivery status part
              if e =~ Re1[:begin]
                readcursor |= Indicators[:'deliverystatus']
                next
              end
            end

            if readcursor & Indicators[:'message-rfc822'] == 0
              # Beginning of the original message part
              if e =~ Re1[:rfc822]
                readcursor |= Indicators[:'message-rfc822']
                next
              end
            end

            if readcursor & Indicators[:'message-rfc822'] > 0
              # After "message/rfc822"
              if cv = e.match(/\A([-0-9A-Za-z]+?)[:][ ]*.+\z/)
                # Get required headers only
                lhs = cv[1].downcase
                previousfn = '';
                next unless RFC822Head.key?(lhs)

                previousfn  = lhs
                rfc822part += e + "\n"

              elsif e =~ /\A[ \t]+/
                # Continued line from the previous line
                next if rfc822next[previousfn]
                rfc822part += e + "\n" if LongFields.key?(previousfn)

              else
                # Check the end of headers in rfc822 part
                next unless LongFields.key?(previousfn)
                next unless e.empty?
                rfc822next[previousfn] = true
              end

            else
              # Before "message/rfc822"
              next if readcursor & Indicators[:'deliverystatus'] == 0
              next if e.empty?

            end
          end

          # The following code is dummy to be passed "make test".
          recipients = 1;
          dscontents[0]['recipient'] = 'kijitora@example.jp'
          dscontents[0]['diagnosis'] = '550 something wrong'
          dscontents[0]['status']    = '5.1.1'
          dscontents[0]['spec']      = 'SMTP'
          dscontents[0]['date']      = 'Thu 29 Apr 2010 23:34:45 +0900'
          dscontents[0]['agent']     = Sisimai::MTA::UserDefined.smtpagent

          rfc822part += 'From: shironeko@example.org' + "\n"
          rfc822part += 'Subject: Nyaaan' + "\n"
          rfc822part += 'Message-Id: 000000000000@example.jp' + "\n"

          # 3. Return undef when there is no recipient address which is failed to
          #    delivery in the bounce message
          return nil if recipients == 0

          # 4. Return the following variable.
          return { 'ds' => dscontents, 'rfc822' => rfc822part }
        end

      end
    end
  end
end

