# Correctness Proof: DispatchToBackgroundThread + APCProc

## Protocol Overview

The protocol uses a **flag + queue** pattern:
- `EventQueue` (a `TThreadedQueue<TProc>`) holds pending work items
- `APCSignaled` (an integer, 0 or 1) gates whether an APC is already in-flight
- Only one APC is active at a time; it drains the entire queue

### Protocol Steps

**Producer** (`DispatchToBackgroundThread`, line 388):
1. Push item into `EventQueue`
2. Atomically exchange `APCSignaled` to 1, read old value
3. If old value was 0 → queue a new APC via `QueueUserAPC`
4. If old value was 1 → skip (an APC is already pending/running)

**Consumer** (`APCProc`, line 404):
1. Drain loop: `PopItem` until queue is empty
2. `ClearAPCFlag` → set `APCSignaled` to 0
3. Re-check: if `QueueSize > 0`, set flag back to 1 and queue another APC

### Key Invariant

**No item can be stranded in the queue.** For an item to be lost, every producer must skip `QueueUserAPC` (seeing `APCSignaled=1`), AND the running APCProc must finish without processing or re-detecting it.

---

## Part 1: Single Producer

### Exhaustive Interleaving Analysis

The only dangerous window is when APCProc has finished draining and is about to clear/check the flag, while the producer is pushing. There are exactly 5 orderings of the 4 operations that matter:

```
Producer ops:    (A) PushItem    (B) Exchange(APCSignaled, 1)
APCProc ops:     (C) ClearAPCFlag(→0)   (D) QueueSize > 0 check
```

**Case 1: A → B → C → D** (producer finishes before APCProc clears)
- B sees old=1 → producer skips QueueUserAPC
- C sets flag to 0
- D sees item from A → APCProc re-queues APC ✅

**Case 2: A → C → B → D**
- C sets flag to 0
- B sees old=0 → producer queues new APC ✅

**Case 3: A → C → D → B**
- C sets flag to 0
- D sees item from A → APCProc sets flag to 1, queues APC
- B sees old=1 → producer skips (correctly, APC already queued) ✅

**Case 4: C → A → B → D**
- C sets flag to 0
- B sees old=0 → producer queues APC
- D sees item → APCProc tries Exchange, gets old=1 (set by B) → skips re-queue (correctly, producer already queued APC) ✅

**Case 5: C → D → A → B** (APCProc finishes before producer pushes)
- D sees empty queue → APCProc exits
- B sees old=0 (cleared in C) → producer queues new APC ✅

In every case, exactly one APC gets queued to process the item.

### The Fundamental Guarantee

The correctness hinges on a **linearization argument**: `PushItem` (A) is always sequenced-before `Exchange` (B) on the producer side, and `ClearAPCFlag` (C) is always sequenced-before `QueueSize` check (D) on the consumer side. This means:

- If the producer sees `APCSignaled=1` at (B), then (C) hasn't happened yet, so (D) will observe the item from (A).
- If the producer sees `APCSignaled=0` at (B), the producer queues its own APC.

There is no "gap" where both sides fail to act.

---

## Part 2: Multiple Simultaneous Producers

### New Concerns

With N producers calling `DispatchToBackgroundThread` concurrently, three new questions arise:

1. Can an item be stranded when multiple producers race on `Exchange`?
2. Can multiple APCs accumulate without bound?
3. Is `TThreadedQueue` safe under concurrent pushes?

### Thread Safety of the Shared State

**`APCSignaled`**: Accessed exclusively via `TInterlocked.Exchange`, which is atomic. Concurrent exchanges are totally ordered by the hardware.

**`EventQueue`**: `TThreadedQueue<TProc>` uses an internal monitor (`TMonitor`) to serialize `PushItem`, `PopItem`, and `QueueSize`. Multiple concurrent pushes are safe; each push completes atomically with respect to the others.

### Atomicity of Exchange Under Multiple Producers

When N producers race on `Exchange(APCSignaled, 1)`, the hardware serializes them into some total order. Exactly one will see `old=0` (the first in that order); all others see `old=1`. Therefore **at most one producer** queues an APC per flag-clear cycle.

### Generalized No-Stranding Proof

**Theorem**: For any item I pushed by any producer P, item I will be processed by some `APCProc` invocation.

**Proof**: Consider item I pushed by producer P.

- P executes `PushItem(I)` at time t₁.
- P executes `Exchange(APCSignaled, 1)` at time t₂ > t₁.

**Case A — P sees old=0**: P queues an APC. That APC will execute and drain the queue. Since I was pushed at t₁ < t₂ (before the APC was queued), and `PopItem` is FIFO, the drain loop will encounter I. ✅

**Case B — P sees old=1**: At time t₂, `APCSignaled` was already 1. Some entity set it — either another producer or APCProc's re-check. This means an APC is either pending or running:

- **Sub-case B1 — APC is pending** (queued but not yet started): When it starts, its drain loop will process all items currently in the queue. Since I was pushed at t₁ < t₂, and the APC starts after it was queued (which was before t₂, since the flag was already 1 at t₂), I is in the queue when the drain loop runs. ✅

- **Sub-case B2 — APC is running** (APCProc is executing its drain loop): The drain loop may or may not pop I:

  - **B2a — Drain loop pops I**: Done. ✅

  - **B2b — Drain loop finishes without popping I**: APCProc then executes:
    1. `ClearAPCFlag` → sets `APCSignaled` to 0
    2. Checks `QueueSize > 0`

    Since I is still in the queue (PushItem completed at t₁, and PopItem hasn't removed it), `QueueSize > 0` is true. APCProc executes `Exchange(APCSignaled, 1)`:

    - If it sees old=0: APCProc queues a new APC → that APC drains I. ✅
    - If it sees old=1: Another producer (or the same P on a subsequent Fire) already set the flag and queued an APC → that APC drains I. ✅

In all cases, I is eventually processed. ∎

### Multi-Producer Interleaving Examples

#### Example 1: Two producers, both items batched into one APC

```
P1: PushItem(proc1)                        queue: [proc1]
P2: PushItem(proc2)                        queue: [proc1, proc2]
P1: Exchange(APCSignaled, 1) → old=0       P1 queues APC
P2: Exchange(APCSignaled, 1) → old=1       P2 skips (correctly)
APC fires: drains proc1, proc2             ✅
```

#### Example 2: Producer races with APCProc flag-clear

```
APCProc:  drain loop finishes              queue: []
APCProc:  ClearAPCFlag → 0
P1:       PushItem(proc1)                  queue: [proc1]
P1:       Exchange → old=0, queues APC
P2:       PushItem(proc2)                  queue: [proc1, proc2]
P2:       Exchange → old=1, skips
APCProc:  QueueSize > 0 → true
APCProc:  Exchange → old=1 (set by P1)     skips re-queue (correctly)
APCProc:  exits
APC (from P1) fires: drains proc1, proc2  ✅
```

#### Example 3: Both producers skip, APCProc re-check catches it

```
APCProc:  drain loop running...
P1:       PushItem(proc1)                  queue: [proc1]
P1:       Exchange → old=1, skips
P2:       PushItem(proc2)                  queue: [proc1, proc2]
P2:       Exchange → old=1, skips
APCProc:  drain loop finishes              (didn't see proc1/proc2)
APCProc:  ClearAPCFlag → 0
APCProc:  QueueSize > 0 → true
APCProc:  Exchange → old=0, queues APC
New APC fires: drains proc1, proc2         ✅
```

#### Example 4: Producer and APCProc both queue APCs (harmless duplication)

```
APCProc #1: drain finishes, ClearAPCFlag → 0
APCProc #1: QueueSize > 0 → true
APCProc #1: Exchange → old=0, queues APC #2
P1:         PushItem(proc_new)
P1:         Exchange → old=1, skips
APCProc #1: exits
APC #2 fires: drains everything            ✅
```

Could both APCProc and a producer see old=0?

```
APCProc:  ClearAPCFlag → 0
P1:       Exchange → old=0, sets to 1      P1 will queue APC #A
APCProc:  QueueSize > 0 → true
APCProc:  Exchange → old=1 (set by P1)     APCProc skips re-queue
P1:       QueueUserAPC → APC #A queued
APC #A fires: drains everything            ✅ (only one APC queued)
```

The reverse:

```
APCProc:  ClearAPCFlag → 0
APCProc:  QueueSize > 0 → true
APCProc:  Exchange → old=0, sets to 1      APCProc will queue APC #A
P1:       Exchange → old=1                 P1 skips (correctly)
APCProc:  QueueUserAPC → APC #A queued
APC #A fires: drains everything            ✅ (only one APC queued)
```

In both orderings, exactly one entity queues the APC.

### APC Accumulation Bound

**Claim**: At most 2 APCs can be pending at any time for a given thread.

**Proof**: An APC is queued only when `Exchange(APCSignaled, 1)` returns old=0. Between any two transitions from 0→1, there must be a 1→0 transition (via `ClearAPCFlag`). `ClearAPCFlag` runs only inside `APCProc`, which means at least one APC has started executing.

In the worst case, the sequence is:
1. APCProc #1 clears flag (0)
2. APCProc #1's re-check queues APC #2 (flag → 1)
3. APCProc #1 exits
4. Before APC #2 starts, another ClearAPCFlag+re-check can't happen (APC #2 hasn't run yet)
5. A producer sees flag=1, skips

So between ClearAPCFlag and the next APC starting to execute, at most one new APC can be queued (by whichever entity — producer or APCProc — wins the Exchange). Combined with the currently-executing APC finishing, at most 2 APCs are in the OS queue. Since APCs are serialized per-thread, this is completely harmless.

### FIFO Ordering

`TThreadedQueue` is FIFO. Under multiple producers, the total order of items in the queue is determined by the order in which their `PushItem` calls acquire the queue's internal monitor. Within a single producer issuing sequential Fire calls, order is preserved. Across producers, the interleaving depends on scheduling, but each individual producer's items maintain their relative order.

---

## Safety Properties (Both Single and Multiple Producers)

1. **No double-processing**: `TThreadedQueue.PopItem` atomically removes items, so no item is returned twice.

2. **APCs are serialized**: Windows executes APCs on a given thread one at a time. Two `APCProc` invocations never run concurrently on the same thread, so the drain-then-clear-then-recheck sequence is always atomic with respect to the consumer side.

3. **Bounded APC accumulation**: At most 2 APCs pending per thread at any time (see proof above).

4. **No livelock**: The drain loop always terminates (finite queue), and the re-check queues at most one additional APC per cycle.

---

## Minor Weaknesses

**1. `PushItem` return value is unchecked** (line 392):

```pascal
state.EventQueue.PushItem(proc);
```

The `TThreadedQueue` constructor uses `PushTimeout=100`. If the queue is full for 100ms, `PushItem` returns `wrTimeout` and the item is **silently dropped**. This isn't a protocol bug but a capacity concern. Under high multi-producer load, this is more likely to occur than with a single producer.

---

## Verdict

The APC coalescing protocol is **correct for both single and multiple simultaneous producers**. Every pushed item is guaranteed to be processed exactly once, assuming the queue doesn't overflow and `QueueUserAPC` doesn't fail on the re-queue path. The `TInterlocked.Exchange` on the shared flag serializes all producers correctly, and APCProc's post-drain re-check closes the only race window where items could otherwise be stranded.
