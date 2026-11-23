# Common behavioral vectors

The SV and BSV environments use these scenarios and expected invariants:

1. Reset is fail closed; C cannot start or write policy.
2. E grants C; C performs a bounded operation and sees a result only when policy
   enables visibility.
3. C cannot alter policy, abort E, exceed the length limit, or read protected data.
4. E and C requests in the same window resolve to E priority.
5. Revocation aborts or drains, clears, invalidates results, and only then grants E.
6. Delayed clear blocks transfer; missing clear acknowledgement enters FAULT.
7. Partial CONFIG/POLICY writes have no protected side effect.
8. AW and W arrive independently and each accepted request receives the response
   on its originating port.
