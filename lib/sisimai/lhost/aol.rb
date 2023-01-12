module Sisimai::Lhost
  # Sisimai::Lhost::Aol parses a bounce email which created by Aol Mail. Methods in the module are
  # called from only Sisimai::Message.
  module Aol
    class << self
      require 'sisimai/lhost'

      Indicators = Sisimai::Lhost.INDICATORS
      Boundaries = ['Content-Type: message/rfc822'].freeze
      StartingOf = { message: ['Content-Type: message/delivery-status'] }.freeze
      MessagesOf = {
        'hostunknown' => ['Host or domain name not found'],
        'notaccept'   => ['type=MX: Malformed or unexpected name server reply'],
      }.freeze

      # Parse bounce messages from Aol Mail
      # @param  [Hash] mhead    Message headers of a bounce email
      # @param  [String] mbody  Message body of a bounce email
      # @return [Hash]          Bounce data list and message/rfc822 part
      # @return [Nil]           it failed to parse or the arguments are missing
      def inquire(mhead, mbody)
        # X-AOL-IP: 192.0.2.135
        # X-AOL-VSS-INFO: 5600.1067/98281
        # X-AOL-VSS-CODE: clean
        # x-aol-sid: 3039ac1afc14546fb98a0945
        # X-AOL-SCOLL-EIL: 1
        # x-aol-global-disposition: G
        # x-aol-sid: 3039ac1afd4d546fb97d75c6
        # X-BounceIO-Id: 9D38DE46-21BC-4309-83E1-5F0D788EFF1F.1_0
        # X-Outbound-Mail-Relay-Queue-ID: 07391702BF4DC
        # X-Outbound-Mail-Relay-Sender: rfc822; shironeko@aol.example.jp
        return nil unless mhead['x-aol-ip']

        require 'sisimai/rfc1894'
        fieldtable = Sisimai::RFC1894.FIELDTABLE
        permessage = {}     # (Hash) Store values of each Per-Message field

        dscontents = [Sisimai::Lhost.DELIVERYSTATUS]
        emailparts = Sisimai::RFC5322.part(mbody, Boundaries)
        bodyslices = emailparts[0].split("\n")
        readslices = ['']
        readcursor = 0      # (Integer) Points the current cursor position
        recipients = 0      # (Integer) The number of 'Final-Recipient' header
        v = nil

        while e = bodyslices.shift do
          # Read error messages and delivery status lines from the head of the email to the previous
          # line of the beginning of the original message.
          readslices << e # Save the current line for the next loop

          if readcursor == 0
            # Beginning of the bounce message or message/delivery-status part
            readcursor |= Indicators[:deliverystatus] if e.start_with?(StartingOf[:message][0])
            next
          end
          next if (readcursor & Indicators[:deliverystatus]) == 0
          next if e.empty?

          if f = Sisimai::RFC1894.match(e)
            # "e" matched with any field defined in RFC3464
            next unless o = Sisimai::RFC1894.field(e)
            v = dscontents[-1]

            if o[-1] == 'addr'
              # Final-Recipient: rfc822; kijitora@example.jp
              # X-Actual-Recipient: rfc822; kijitora@example.co.jp
              if o[0] == 'final-recipient'
                # Final-Recipient: rfc822; kijitora@example.jp
                if v['recipient']
                  # There are multiple recipient addresses in the message body.
                  dscontents << Sisimai::Lhost.DELIVERYSTATUS
                  v = dscontents[-1]
                end
                v['recipient'] = o[2]
                recipients += 1
              else
                # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                v['alias'] = o[2]
              end
            elsif o[-1] == 'code'
              # Diagnostic-Code: SMTP; 550 5.1.1 <userunknown@example.jp>... User Unknown
              v['spec'] = o[1]
              v['diagnosis'] = o[2]
            else
              # Other DSN fields defined in RFC3464
              next unless fieldtable[o[0]]
              v[fieldtable[o[0]]] = o[2]

              next unless f == 1
              permessage[fieldtable[o[0]]] = o[2]
            end
          else
            # Continued line of the value of Diagnostic-Code field
            next unless readslices[-2].start_with?('Diagnostic-Code:')
            next unless cv = e.match(/\A[ ]+(.+)\z/)
            v['diagnosis'] << ' ' << cv[1]
            readslices[-1] = 'Diagnostic-Code: ' << e
          end
        end
        return nil unless recipients > 0

        dscontents.each do |e|
          # Set default values if each value is empty.
          e['lhost'] ||= permessage['rhost']
          permessage.each_key { |a| e[a] ||= permessage[a] || '' }
          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'].tr("\n", ' '))

          MessagesOf.each_key do |r|
            # Verify each regular expression of session errors
            next unless MessagesOf[r].any? { |a| e['diagnosis'].include?(a) }
            e['reason'] = r
            break
          end

          if e['status'].empty? || e['status'].end_with?('.0.0')
            # There is no value of Status header or the value is 5.0.0, 4.0.0
            e['status'] = Sisimai::SMTP::Status.find(e['diagnosis']) || ''
          end
        end

        return { 'ds' => dscontents, 'rfc822' => emailparts[1] }
      end
      def description; return 'Aol Mail: https://www.aol.com'; end
    end
  end
end

