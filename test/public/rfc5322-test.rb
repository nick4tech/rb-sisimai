require 'minitest/autorun'
require 'sisimai/rfc5322'

class RFC5322Test < Minitest::Test
  Methods = { class: %w[HEADERFIELDS LONGFIELDS FIELDINDEX received part] }
  ReceivedList = [
    'from mx.example.org (c182128.example.net [192.0.2.128]) by mx.example.jp (8.14.4/8.14.4) with ESMTP id oBB3JxRJ022484 for <shironeko@example.jp>; Sat, 11 Dec 2010 12:20:00 +0900 (JST)',
    'from localhost (localhost [127.0.0.1]) (ftp://ftp.isi.edu/in-notes/rfc1894.txt) by marutamachi.example.org with dsn; Sat, 11 Dec 2010 12:19:59 +0900',
    'from [127.0.0.1] (c10920.example.com [192.0.2.20]) by marutamachi.example.org with SMTP; Sat, 11 Dec 2010 12:19:17 +0900 id 0EFECD4E.4D02EDD9.0000C5BA',
    'from host (HELO exchange.example.co.jp) (192.0.2.57) by 0 with SMTP; 29 Apr 2007 23:19:00 -0000',
    'from mail by marutamachi.example.org with local (Exim 4.72) id 1X58pT-0004bZ-Co for shironeko@example.jp; Thu, 10 Jul 2014 16:31:43 +0900',
    'from mail4.example.co.jp (1234c.example.com [192.0.2.1]) by mx.example.jp (8.14.4/8.14.4) with ESMTP id r4B0078w00000 for <postmaster@example.jp>; Mon, 11 #May 2013 00:00:00 +0900 (JST)',
    '(from webmaster@localhost) by mail4.example.co.jp (8.14.4/8.14.4/Submit) id r4B003v000000 for shironeko@example.ne.jp; Mon, 11 May 2013 00:00:00 +0900',
    'from biglobe.ne.jp by rcpt-expgw4.biglobe.ne.jp (0000/0000000000) with SMTP id p0000000000000 for <kijitora@mx.example.com>; Thu, 11 Feb 2014 00:00:00 +090#0',
    'from wfilter115 (wfilter115-a0 [172.26.26.68]) by wsmtpr24.ezweb.ne.jp (EZweb Mail) with ESMTP id EF283A071 for <user@example.or.jp>; Sun,  7 Sep 2008 21:4#0:12 +0900 (JST)',
    'from vagrant-centos65.example.com (c213502.kyoto.example.ne.jp [192.0.2.135]) by aneyakoji.example.jp (V8/cf) with ESMTP id s6HB0VsJ028505 for <kijitora@ex#ample.jp>; Thu, 17 Jul 2014 20:00:32 +0900',
    'from localhost (localhost [local]); by localhost (OpenSMTPD) with ESMTPA id 1e2a9eaa; for <kijitora@example.jp>;',
    'from [127.0.0.1] (unknown [172.25.191.1]) by smtp.example.com (Postfix) with ESMTP id 7874F1FB8E; Sat, 21 Jun 2014 18:34:34 +0000 (UTC)',
    'from unknown (HELO ?127.0.0.1?) (172.25.73.1) by 172.25.73.144 with SMTP; 1 Jul 2014 08:30:40 -0000',
    'from [192.0.2.25] (p0000-ipbfpfx00kyoto.kyoto.example.co.jp [192.0.2.25]) (authenticated bits=0) by smtpgw.example.jp (V8/cf) with ESMTP id r9G5FXh9018568',
    'from localhost (localhost) by nijo.example.jp (V8/cf) id s1QB5ma0018057; Wed, 26 Feb 2014 06:05:48 -0500',
    'by 10.194.5.104 with SMTP id r8csp190892wjr; Fri, 18 Jul 2014 00:31:04 -0700 (PDT)',
    'from gargamel.example.com (192.0.2.146) by athena.internal.example.com with SMTP; 12 Jun 2013 02:22:14 -0000',
  ]
  EmailMessage = '
This is a MIME-encapsulated message

The original message was received at Thu, 9 Apr 2014 23:34:45 +0900
from localhost [127.0.0.1]

   ----- The following addresses had permanent fatal errors -----
<kijitora@example.net>
    (reason: 551 not our customer)
   ----- Transcript of session follows -----
... while talking to mx-0.neko.example.jp.:
<<< 450 busy - please try later
... while talking to mx-1.neko.example.jp.:
>>> DATA
<<< 551 not our customer
550 5.1.1 <kijitora@example.net>... User unknown
<<< 503 need RCPT command [data]

Content-Type: message/delivery-status
Reporting-MTA: dns; mx.example.co.jp
Received-From-MTA: DNS; localhost
Arrival-Date: Thu, 9 Apr 2014 23:34:45 +0900

Final-Recipient: RFC822; kijitora@example.net
Action: failed
Status: 5.1.6
Remote-MTA: DNS; mx-s.neko.example.jp
Diagnostic-Code: SMTP; 551 not our customer
Last-Attempt-Date: Thu, 9 Apr 2014 23:34:45 +0900

Content-Type: message/rfc822
Return-Path: <shironeko@mx.example.co.jp>
Received: from mx.example.co.jp (localhost [127.0.0.1])
	by mx.example.co.jp (8.13.9/8.13.1) with ESMTP id fffff000000001
	for <kijitora@example.net>; Thu, 9 Apr 2014 23:34:45 +0900
Received: (from shironeko@localhost)
	by mx.example.co.jp (8.13.9/8.13.1/Submit) id fff0000000003
	for kijitora@example.net; Thu, 9 Apr 2014 23:34:45 +0900
Date: Thu, 9 Apr 2014 23:34:45 +0900
Message-Id: <0000000011111.fff0000000003@mx.example.co.jp>
content-type:       text/plain
MIME-Version: 1.0
From: Shironeko <shironeko@example.co.jp>
To: Kijitora <shironeko@example.co.jp>
Subject: Nyaaaan

Nyaaan
__END_OF_EMAIL_MESSAGE__
'

  def test_methods
    Methods[:class].each { |e| assert_respond_to Sisimai::RFC5322, e }
  end

  def test_FIELDINDEX
    cv = Sisimai::RFC5322.FIELDINDEX
    assert_instance_of Array, cv
    refute_empty cv

    cv.each do |e|
      assert_match /\A[A-Z][A-Za-z-]+\z/, e
    end
  end

  def test_HEADERFIELDS
    cv = Sisimai::RFC5322.HEADERFIELDS
    assert_instance_of Hash, cv
    refute_empty cv

    cv.each_key do |e|
      assert_match /\A[a-z-]+\z/, e
      assert_equal true, cv[e]
    end

    cv = Sisimai::RFC5322.HEADERFIELDS(:date)
    assert_instance_of Array, cv
    refute_empty cv
    cv.each { |e| assert_match /\A[a-z-]+\z/, e }

    cv = Sisimai::RFC5322.HEADERFIELDS('neko')
    assert_instance_of Hash, cv
    refute_empty cv

    cv.each_key do |e|
      assert_instance_of Array, cv[e]
      refute_empty cv[e]

      cv[e].each do |ee|
        assert_instance_of String, ee
        assert_match /\A[a-z-]+\z/, ee
      end
    end

    ce = assert_raises ArgumentError do
      Sisimai::RFC5322.HEADERFIELDS(nil, nil)
    end
  end

  def test_LONGFIELDS
    cv = Sisimai::RFC5322.LONGFIELDS
    assert_instance_of Hash, cv
    cv.each_key do |e|
      assert_match /\A[a-z-]+\z/, e
      assert_equal true, cv[e]
    end

    ce = assert_raises ArgumentError do
      Sisimai::RFC5322.LONGFIELDS(nil)
    end
  end

  def test_received
    ReceivedList.each do |e|
      cv = Sisimai::RFC5322.received(e)
      assert_instance_of Array, cv
      refute_empty cv

      cv.each do |ee|
        assert_instance_of String, ee
        assert_match %r{\A[-/:.0-9A-Za-z]+\z}, ee
      end
    end

    ce = assert_raises ArgumentError do
      Sisimai::RFC5322.received()
      Sisimai::RFC5322.received(nil, nil)
    end
    assert_equal [], Sisimai::RFC5322.received(nil)
  end

  def test_part
    emailpart1 = Sisimai::RFC5322.part(EmailMessage, ['Content-Type: message/rfc822'])
    assert_instance_of Array, emailpart1
    assert_equal 2, emailpart1.size
    assert_instance_of String, emailpart1[0]
    assert_instance_of String, emailpart1[1]

    assert_match /^Final-Recipient: /, emailpart1[0]
    assert_match /^Subject: /,         emailpart1[1]
    refute_match /^Return-Path: /,     emailpart1[0]
    refute_match /binary$/,            emailpart1[0]
    refute_match /^Remote-MTA: /,      emailpart1[1]
    refute_match /^Neko-Nyaan/,        emailpart1[1]

    emailpart2 = Sisimai::RFC5322.part(EmailMessage, ['Content-Type: message/rfc822'], true)
    assert_instance_of Array, emailpart2
    assert_equal 2, emailpart2.size
    assert_instance_of String, emailpart2[0]
    assert_instance_of String, emailpart2[1]

    assert_match /^Final-Recipient: /, emailpart2[0]
    assert_match /^Subject: /,         emailpart2[1]
    refute_match /^Return-Path: /,     emailpart2[0]
    refute_match /binary$/,            emailpart2[0]
    refute_match /^Remote-MTA: /,      emailpart2[1]
    refute_match /^Neko-Nyaan/,        emailpart2[1]

    assert_equal true, (emailpart1[1].size < emailpart2[1].size)
  end

end

