//
// Copyright (c) 2010, Brian Frank and Andy Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Feb 10 Brian Frank  Creation
//

**
** AtomicInt is used to manage an integer variable shared
** between actor/threads with atomic updates.
**
@Js
final const class AtomicInt
{

  **
  ** Construct with initial value
  **
  new make(Int val := 0) { this.val = val }

  **
  ** The current integer value
  **
  native Int val

  **
  ** Atomically set the value and return the previous value.
  **
  native Int getAndSet(Int val)

  **
  ** Atomically set the value to 'update' if current value is
  ** equivalent to the 'expect' value.  Return true if updated, or
  ** false if current value was not equal to the expected value.
  **
  native Bool compareAndSet(Int expect, Int update)

  **
  ** Atomically increment the current value by one and
  ** return the previous value.
  **
  native Int getAndIncrement()

  **
  ** Atomically decrement the current value by one and
  ** return the previous value.
  **
  native Int getAndDecrement()

  **
  ** Atomically add the given value to the current value
  ** and return the previous value.
  **
  native Int getAndAdd(Int delta)

  **
  ** Atomically increment the current value by one and
  ** return the updated value.
  **
  native Int incrementAndGet()

  **
  ** Atomically decrement the current value by one and
  ** return the updated value.
  **
  native Int decrementAndGet()

  **
  ** Atomically add the given value to the current value and
  ** return the updated value.
  **
  native Int addAndGet(Int delta)

  **
  ** Atomically increment the value by one
  **
  native Void increment()

  **
  ** Atomically decrement the value by one
  **
  native Void decrement()

  **
  ** Atomically add the given value to the current value
  **
  native Void add(Int delta)

  **
  ** Return 'val.toStr'
  **
  override Str toStr() { val.toStr }

}