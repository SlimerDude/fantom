//
// Copyright (c) 2007, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jan 07  Brian Frank  Creation
//   26 Mar 09  Brian Frank  Split from old ThreadTest
//

**
** ActorTest
**
class ActorTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Setup/Teardown
//////////////////////////////////////////////////////////////////////////

  ActorPool pool := ActorPool()

  override Void teardown() { pool.kill }

//////////////////////////////////////////////////////////////////////////
// Make
//////////////////////////////////////////////////////////////////////////

  Void testMake()
  {
    mutable := |Context cx, Obj? msg->Obj?| { fail; return null }
    verifyErr(ArgErr#) { x := Actor(pool) }
    verifyErr(NotImmutableErr#) { x := Actor(pool, mutable) }
  }

//////////////////////////////////////////////////////////////////////////
// Context
//////////////////////////////////////////////////////////////////////////

  Void testContext()
  {
    a := Actor(ActorPool()) |msg, Context cx|
    {
      switch (msg)
      {
        case "get":  return cx->foo
        case "zero": return cx->foo = 0
        case "inc":  return cx->foo = 1 + cx->foo
      }
      return 99
    }

    verifyErr(UnknownSlotErr#) { a.send("get").get }
    verifyEq(a.send("zero").get, 0)
    verifyEq(a.send("inc").get, 1)
    verifyEq(a.send("inc").get, 2)
    verifyEq(a.send("get").get, 2)
    verifyEq(a.send("zero").get, 0)
    verifyEq(a.send("get").get, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    // create actor which increments an Int
    g := ActorPool()
    a := Actor(pool, #incr.func)

    // verify basic identity
    verifyEq(g.type, ActorPool#)
    verifyEq(a.type, Actor#)
    verifySame(a.pool, pool)
    verifyEq(g.isStopped, false)
    verifyEq(g.isDone, false)

    // fire off a bunch of Ints and verify
    futures := Future[,]
    100.times |Int i| { futures.add(a.send(i)) }
    futures.each |Future f, Int i|
    {
      verifyEq(f.type, Future#)
      verifyEq(f.get, i+1)
      verify(f.isDone)
      verify(!f.isCancelled)
      verifyEq(f.get, i+1)
    }
  }

  static Int incr(Int msg, Context cx)
  {
    if (cx.type != Context#) echo("ERROR: Context.type hosed")
    return msg+1
  }

//////////////////////////////////////////////////////////////////////////
// Ordering
//////////////////////////////////////////////////////////////////////////

  Void testOrdering()
  {
    // build a bunch actors
    actors := Actor[,]
    200.times { actors.add(Actor(pool, #order.func)) }

    // randomly send increasing ints to the actors
    100_000.times |Int i| { actors[Int.random(0..<actors.size)].send(i) }

    // get the results
    futures := Future[,]
    actors.each |Actor a, Int i| { futures.add(a.send("result-$i")) }

    futures.each |Future f, Int i|
    {
      Int[] r := f.get
      r.each |Int v, Int j| { if (j > 0) verify(v > r[j-1]) }
    }
  }

  static Obj? order(Obj msg, Context cx)
  {
    Int[]? r := cx.get("foo")
    if (r == null) cx.set("foo", r = Int[,])
    if (msg.toStr.startsWith("result")) return r
    r.add(msg)
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  Void testMessaging()
  {
    a := Actor(pool, #messaging.func)

    // const
    f := a.send("const")
    verifySame(f.get, a)
    verifySame(f.get, a)
    verify(f.isDone)

    // serializable
    f = a.send("serial")
    verifyEq(f.get, SerA { i = 123_321 })
    verifyEq(f.get, SerA { i = 123_321 })
    verifyNotSame(f.get, f.get)
    verify(f.isDone)

    // non-serializable mutables
    verifyErr(IOErr#) { a.send(this) }
    verifyErr(IOErr#) { a.send("mutable").get }

    // receive raises error
    f = a.send("throw")
    verifyErr(UnknownServiceErr#) { f.get }
    verifyErr(UnknownServiceErr#) { f.get }
    verify(f.isDone)
  }

  static Obj? messaging(Str msg, Context cx)
  {
    switch (msg)
    {
      case "const":   return cx.actor
      case "serial":  return SerA { i = 123_321 }
      case "throw":   throw UnknownServiceErr()
      case "mutable": return cx
      default: return "?"
    }
  }

//////////////////////////////////////////////////////////////////////////
// Timeout/Cancel
//////////////////////////////////////////////////////////////////////////

  Void testTimeoutCancel()
  {
    a := Actor(pool, #sleep.func)
    f := a.send(1sec)

    // get with timeout
    t1 := Duration.now
    verifyErr(TimeoutErr#) { f.get(50ms) }
    t2 := Duration.now
    verify(t2-t1 < 70ms, (t2-t1).toLocale)

    // launch an actor to cancel the future
    Actor(pool, |msg| {cancel(msg)}).send(f)

    // block on future until canceled
    verifyErr(CancelledErr#) { f.get }
    verifyErr(CancelledErr#) { f.get }
    verify(f.isDone)
    verify(f.isCancelled)
  }

  static Obj? sleep(Obj? msg)
  {
    if (msg is Duration) Actor.sleep(msg)
    return msg
  }

  static Obj? cancel(Future f)
  {
    Actor.sleep(20ms)
    f.cancel
    return f
  }

//////////////////////////////////////////////////////////////////////////
// Stop
//////////////////////////////////////////////////////////////////////////

  Void testStop()
  {
    // launch a bunch of threads which sleep for a random time
    actors := Actor[,]
    durs := Duration[,]
    futures := Future[,]
    scheduled := Future[,]
    20.times |Int i|
    {
      actor := Actor(pool, #sleep.func)
      actors.add(actor)

      // send some dummy messages
      Int.random(100..<1000).times |Int j| { actor.send(j) }

      // send sleep duration 0 to 300ms
      dur := 1ms * Int.random(0..<300).toFloat
      if (i == 0) dur = 300ms
      durs.add(dur)
      futures.add(actor.send(dur))

      // schedule some messages in future well after we stop
      3.times |Int j| { scheduled.add(actor.sendLater(10sec + 1sec * j.toFloat, j)) }
    }

    // still running
    verifyEq(pool.isStopped, false)
    verifyEq(pool.isDone, false)
    verifyErr(Err#) { pool.join }
    verifyErr(Err#) { pool.join(5sec) }

    // join with timeout
    t1 := Duration.now
    verifyErr(TimeoutErr#) { pool.stop.join(100ms) }
    t2 := Duration.now
    verify(t2 - t1 <= 120ms)
    verifyEq(pool.isStopped, true)
    verifyEq(pool.isDone, false)

    // verify can't send or schedule anymore
    actors.each |Actor a|
    {
      verifyErr(Err#) { a.send(10sec) }
      verifyErr(Err#) { a.sendLater(1sec, 1sec) }
    }

    // stop again, join with no timeout
    pool.stop.join
    t2 = Duration.now
    verify(t2 - t1 <= 340ms, (t2-t1).toLocale)
    verifyEq(pool.isStopped, true)
    verifyEq(pool.isDone, true)

    // verify all futures have completed
    futures.each |Future f| { verify(f.isDone) }
    futures.each |Future f, Int i| { verifyEq(f.get, durs[i]) }

    // verify all scheduled messages were canceled
    verifyAllCancelled(scheduled)
  }

  Void verifyAllCancelled(Future[] futures)
  {
    futures.each |Future f|
    {
      verify(f.isDone)
      verify(f.isCancelled)
      verifyErr(CancelledErr#) { f.get }
      verifyErr(CancelledErr#) { f.get(200ms) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Kill
//////////////////////////////////////////////////////////////////////////

  Void testKill()
  {
    // spawn off a bunch of actors and sleep messages
    futures := Future[,]
    durs := Duration[,]
    scheduled := Future[,]
    200.times |->|
    {
      actor := Actor(pool, #sleep.func)

      // send 6x 0ms - 50ms, max 600ms
      6.times |Int i|
      {
        dur := 1ms * Int.random(0..<50).toFloat
        futures.add(actor.send(dur))
        durs.add(dur)
      }

      // schedule some messages in future well after we stop
      scheduled.add(actor.sendLater(3sec, actor))
    }

    verifyEq(pool.isStopped, false)
    verifyEq(pool.isDone, false)

    // kill
    t1 := Duration.now
    pool.kill
    verifyEq(pool.isStopped, true)

    // verify can't send anymore
    verifyErr(Err#) { Actor(pool, #sleep.func).send(10sec) }

    // join
    pool.join
    t2 := Duration.now
    verify(t2-t1 < 50ms, (t2-t1).toLocale)
    verifyEq(pool.isStopped, true)
    verifyEq(pool.isDone, true)

    // verify all futures must now be done one of three ways:
    //  1) completed successfully
    //  2) were interrupted (if running during kill)
    //  3) were cancelled (if pending)
    futures.each |Future f, Int i| { verify(f.isDone, "$i ${durs[i]}") }
    futures.each |Future f, Int i|
    {
      // each future either
      if (f.isCancelled)
      {
        verifyErr(CancelledErr#) { f.get }
      }
      else
      {
        try
          verifyEq(f.get, durs[i])
        catch (InterruptedErr e)
          verifyErr(InterruptedErr#) { f.get }
      }
    }

    // verify all scheduled messages were canceled
    verifyAllCancelled(scheduled)
  }

//////////////////////////////////////////////////////////////////////////
// Later
//////////////////////////////////////////////////////////////////////////

  Void testLater()
  {
    // warm up a threads with dummy requests
    receive := |Obj? msg->Obj?| { returnNow(msg) }
    5.times { Actor(pool, receive).sendLater(10ms, "dummy") }

    start := Duration.now
    x100 := Actor(pool, receive).sendLater(100ms, null)
    x150 := Actor(pool, receive).sendLater(150ms, null)
    x200 := Actor(pool, receive).sendLater(200ms, null)
    x250 := Actor(pool, receive).sendLater(250ms, null)
    x300 := Actor(pool, receive).sendLater(300ms, null)
    verifyLater(start, x100, 100ms)
    verifyLater(start, x150, 150ms)
    verifyLater(start, x200, 200ms)
    verifyLater(start, x250, 250ms)
    verifyLater(start, x300, 300ms)

    start = Duration.now
    x100 = Actor(pool, |msg| {returnNow(msg)}).sendLater(100ms, null)
    verifyLater(start, x100, 100ms)

    start = Duration.now
    x300 = Actor(pool, receive).sendLater(300ms, null)
    x200 = Actor(pool, receive).sendLater(200ms, null)
    x100 = Actor(pool, receive).sendLater(100ms, null)
    x150 = Actor(pool, receive).sendLater(150ms, null)
    x250 = Actor(pool, receive).sendLater(250ms, null)
    verifyLater(start, x100, 100ms)
    verifyLater(start, x150, 150ms)
    verifyLater(start, x200, 200ms)
    verifyLater(start, x250, 250ms)
    verifyLater(start, x300, 300ms)
  }

  Void testLaterRand()
  {
    // warm up a threads with dummy requests
    5.times { Actor(pool, #returnNow.func).sendLater(10ms, "dummy") }

    // schedule a bunch of actors and messages with random times
    start := Duration.now
    actors := Actor[,]
    futures := Future[,]
    durs := Duration?[,]
    5.times |->|
    {
      a := Actor(pool, #returnNow.func)
      10.times |->|
      {
        // schedule something randonly between 0ms and 1sec
        Duration? dur := 1ms * Int.random(0..<1000).toFloat
        f := a.sendLater(dur, dur)

        // cancel some anything over 500ms
        if (dur > 500ms) { f.cancel; dur = null }

        durs.add(dur)
        futures.add(f)
      }
    }

    // verify cancellation or that scheduling was reasonably accurate
    futures.each |Future f, Int i| { verifyLater(start, f, durs[i], 100ms) }
  }

  Void verifyLater(Duration start, Future f, Duration? expected, Duration tolerance := 20ms)
  {
    if (expected == null)
    {
      verify(f.isCancelled)
      verify(f.isDone)
      verifyErr(CancelledErr#) { f.get }
    }
    else
    {
      Duration actual := (Duration)f.get(3sec) - start
      diff := (expected - actual).abs
      // echo("$expected.toLocale != $actual.toLocale ($diff.toLocale)")
      verify(diff < tolerance, "$expected.toLocale != $actual.toLocale ($diff.toLocale)")
    }
  }

  static Obj? returnNow(Obj? msg) { Duration.now }

//////////////////////////////////////////////////////////////////////////
// When Done
//////////////////////////////////////////////////////////////////////////

  Void testWhenDone()
  {
    a := Actor(pool, #whenDoneA.func)
    b := Actor(pool, #whenDoneB.func)
    c := Actor(pool, #whenDoneB.func)

    // send/complete normal,error,cancel on a
    a.send(50ms)
    a0 := a.send("start")
    a1 := a.send("throw")
    a2 := a.send("cancel")
    a2.cancel
    verifyEq(a0.get, "start")
    verifyErr(IndexErr#) { a1.get }
    verifyErr(CancelledErr#) { a2.get }

    // send some messages with futures already done
    b0 := b.sendWhenDone(a0, a0); c0 := c.sendWhenDone(a0, a0)
    b1 := b.sendWhenDone(a1, a1); c1 := c.sendWhenDone(a1, a1)
    b2 := b.sendWhenDone(a2, a2); c2 := c.sendWhenDone(a2, a2)

    // get some pending messages sent to a
    a.send(50ms)
    a3 := a.send("foo")
    a4 := a.send("bar")
    a5 := a.send("throw")
    ax := a.send("cancel again")
    a6 := a.send("baz")

    // send some messages with futures not done yet
    b3 := b.sendWhenDone(a3, a3); c3 := c.sendWhenDone(a3, a3)
    b4 := b.sendWhenDone(a4, a4); c4 := c.sendWhenDone(a4, a4)
    b5 := b.sendWhenDone(a5, a5); c5 := c.sendWhenDone(a5, a5)
    bx := b.sendWhenDone(ax, ax); cx := c.sendWhenDone(ax, ax)
    b6 := b.sendWhenDone(a6, a6); c6 := c.sendWhenDone(a6, a6)

    // cancel ax (this should happen before a3, a4, etc)
    ax.cancel

    // verify
    verifyWhenDone(b0, c0, "start")
    verifyWhenDone(b1, c1, "start,IndexErr")
    verifyWhenDone(b2, c2, "start,IndexErr,CancelledErr")
    verifyWhenDone(bx, cx, "start,IndexErr,CancelledErr,CancelledErr")
    verifyWhenDone(b3, c3, "start,IndexErr,CancelledErr,CancelledErr,foo")
    verifyWhenDone(b4, c4, "start,IndexErr,CancelledErr,CancelledErr,foo,bar")
    verifyWhenDone(b5, c5, "start,IndexErr,CancelledErr,CancelledErr,foo,bar,IndexErr")
    verifyWhenDone(b6, c6, "start,IndexErr,CancelledErr,CancelledErr,foo,bar,IndexErr,baz")
  }

  Void verifyWhenDone(Future b, Future c, Str expected)
  {
    verifyEq(b.get(2sec), expected)
    verifyEq(c.get(2sec), expected)
  }

  static Obj? whenDoneA(Obj? msg)
  {
    if (msg == "throw") throw IndexErr()
    if (msg is Duration) Actor.sleep(msg)
    return msg
  }

  static Obj? whenDoneB(Future msg, Context cx)
  {
    Str x := cx.get("x", "")
    if (!x.isEmpty) x += ","
    if (!msg.isDone) throw Err("not done yet!")
    try
      x += msg.get.toStr
    catch (Err e)
      x += e.type.name
    cx["x"] = x
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Coalescing (no funcs)
//////////////////////////////////////////////////////////////////////////

  Void testCoalescing()
  {
    a := Actor.makeCoalescing(pool, null, null, #coalesce.func)
    fstart  := a.send(100ms)

    f1s := Future[,]
    f2s := Future[,]
    f3s := Future[,]
    f4s := Future[,]
    ferr := Future[,]
    fcancel := Future[,]

    f1s.add(a.send("one"))
    fcancel.add(a.send("cancel"))
    f2s.add(a.send("two"))
    f1s.add(a.send("one"))
    f2s.add(a.send("two"))
    f3s.add(a.send("three"))
    ferr.add(a.send("throw"))
    f4s.add(a.send("four"))
    fcancel.add(a.send("cancel"))
    f1s.add(a.send("one"))
    ferr.add(a.send("throw"))
    f4s.add(a.send("four"))
    fcancel.add(a.send("cancel"))
    fcancel.add(a.send("cancel"))
    f3s.add(a.send("three"))
    ferr.add(a.send("throw"))
    ferr.add(a.send("throw"))

    fcancel.first.cancel

    a.send(10ms).get(2sec) // wait until completed

    verifyAllSame(f1s)
    verifyAllSame(f2s)
    verifyAllSame(f3s)
    verifyAllSame(f4s)
    verifyAllSame(ferr)
    verifyAllSame(fcancel)

    f1s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["one"]) }
    f2s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["one", "two"]) }
    f3s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["one", "two", "three"]) }
    f4s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["one", "two", "three", "four"]) }
    ferr.each |Future f| { verify(f.isDone); verifyErr(IndexErr#) { f.get } }
    verifyAllCancelled(fcancel)
  }

  static Obj? coalesce(Obj? msg, Context cx)
  {
    if (msg is Duration) { Actor.sleep(msg); cx["msgs"] = Str[,]; return msg }
    if (msg == "throw") throw IndexErr("foo bar")
    Str[] msgs := cx.get("msgs")
    msgs.add(msg)
    return msgs
  }

  Void verifyAllSame(Obj[] list)
  {
    x := list.first
    list.each |Obj y| { verifySame(x, y) }
  }

//////////////////////////////////////////////////////////////////////////
// Coalescing (with funcs)
//////////////////////////////////////////////////////////////////////////

  Void testCoalescingFunc()
  {
    a := Actor.makeCoalescing(pool,
      #coalesceKey.func,
      #coalesceCoalesce.func,
      #coalesceReceive.func)

    fstart  := a.send(100ms)

    f1s := Future[,]
    f2s := Future[,]
    f3s := Future[,]
    ferr := Future[,]
    fcancel := Future[,]

    ferr.add(a.send(["throw"]))
    f1s.add(a.send(["1", 1]))
    f2s.add(a.send(["2", 10]))
    f2s.add(a.send(["2", 20]))
    ferr.add(a.send(["throw"]))
    f2s.add(a.send(["2", 30]))
    fcancel.add(a.send(["cancel"]))
    fcancel.add(a.send(["cancel"]))
    f3s.add(a.send(["3", 100]))
    f1s.add(a.send(["1", 2]))
    f3s.add(a.send(["3", 200]))
    fcancel.add(a.send(["cancel"]))
    ferr.add(a.send(["throw"]))

    fcancel.first.cancel

    a.send(10ms).get(2sec) // wait until completed

    verifyAllSame(f1s)
    verifyAllSame(f2s)
    verifyAllSame(f3s)
    verifyAllSame(ferr)
    verifyAllSame(fcancel)

    f1s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["1", 1, 2]) }
    f2s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["2", 10, 20, 30]) }
    f3s.each |Future f| { verify(f.isDone); verifyEq(f.get, ["3", 100, 200]) }
    ferr.each |Future f| { verify(f.isDone); verifyErr(IndexErr#) { f.get } }
    verifyAllCancelled(fcancel)
  }

  static Obj? coalesceKey(Obj? msg)
  {
    msg is List ? msg->get(0): null
  }

  static Obj? coalesceCoalesce(Obj[] a, Obj[] b)
  {
    Obj[,].add(a[0]).addAll(a[1..-1]).addAll(b[1..-1])
  }

  static Obj? coalesceReceive(Obj? msg)
  {
    if (msg is Duration) { Actor.sleep(msg); return msg }
    if (msg->first == "throw") throw IndexErr("foo bar")
    return msg
  }

//////////////////////////////////////////////////////////////////////////
// Locals
//////////////////////////////////////////////////////////////////////////

  Void testLocals()
  {
    // schedule a bunch of actors (more than thread pool)
    actors := Actor[,]
    locales := Locale[,]
    localesPool := [Locale("en-US"), Locale("en-UK"), Locale("fr"), Locale("ja")]
    300.times |Int i|
    {
      locale := localesPool[Int.random(0..<localesPool.size)]
      actors.add(Actor(pool, |msg| { locals(i, locale, msg) }))
      locales.add(locale)
      actors.last.send("bar")
    }

    actors.each |Actor a, Int i|
    {
      verifyEq(a.send("foo").get, "$i " + locales[i])
    }
  }

  static Obj? locals(Int num, Locale locale, Obj? msg)
  {
    // first time thru
    if (Actor.locals["testLocal"] == null)
    {
      Actor.locals["testLocal"] = num
      Locale.setCur(locale)
    }

    return Actor.locals["testLocal"].toStr + " " + Locale.cur
  }

}