# API Routes Documentation - Version 0.1.0.alpha

This document contain details on the Alces Flight Center API. This is a small subset of the total available routes provided by the application. Routes for the GUI web front end are out of scope of this document.

The API conforms to the standards as described in [RFC 7231](https://tools.ietf.org/html/rfc7231) but does not conform to a standard REST architecture by design.

## Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [BCP 14](https://tools.ietf.org/html/bcp14) \[[RFC2119](https://tools.ietf.org/html/rfc2119)\] \[[RFC8174](https://tools.ietf.org/html/rfc8174)\] when, and only when, they appear in all capitals, as shown here.

The following terms within this document are to be interpreted as meaning:
* `compute units` - The main currency that can be spent through this API,
* `allocate` - The process of redeeming service credit(s) for additional `compute units`,
* `available credits` - A pool of service credits that a `request` MAY `allocate` via an automated mechanism, and
* `required credits` - A hypothetical pool of service credits that a request MUST `allocate` to maintain a non-zero `compute unit` balance.

## URI Leader and Authorization

This application uses Json Web Tokens as described in [RFC 7519](https://tools.ietf.org/html/rfc7519) to authenticate and authorize all API requests. Refer to the [main documentation](../README.md) on how to generate the API `token`. As Alces Flight Center is a multi-tenanted application, the API has been mounted at multiple `leader` positions which correspond to each `site`. Each `token` SHALL only authorize access to a single site and SHOULD NOT be used with all `leader` positions.

All `leader` positions MUST take the form of either:
* `/`
* `/site/:id`

The primary `leader` position for the API is the root URI `/`. This allows the multi-tenanted nature of the application to be hidden from the end user. All requests to the root `leader` MUST have a valid `token`. The response MUST return `401 Unauthorized` if the `token` can not be verified, which includes but is not limited to the following conditions: omitted tokens, expired tokens, syntax errors, and invalid signatures. The response MUST return `403 Forbidden` if the `role` attribute within `token` is not set to "api" or if the following attributes have not been set: `token_id`, `exp`, and `resource`. The response MUST return `404 Not Found` if the `resource` attribute within the `token` is not a global ID URI that corresponds to a valid `site`.

The secondary `leader` positions are unique to a site and take the following format: `/site/:id`. The `id` SHOULD be alphanumeric and match the routes used in the main application GUI. The `id` MAY be an integer identifier that corresponds to a `site`. All requests to a site specific `leader` position MUST have a valid `token`. The `token` SHALL be subject to the same constraints described above for the root `leader` position as well as the following. The response MUST return `403 Forbidden` if the `resource` attribute within the `token` does not correspond to the `site` described by the `leader`.

Requests SHOULD be made to the primary/ root `leader` position where the `token` acts as the canonical source for which `site` the action is being preformed on. Requests to the root `leader` are less likely to return a `403 Forbidden` as the identity of the site is not checked beyond its existence. 

Requests SHOULD be made to a secondary `leader` position where the identity of the `site` is known in advance from a source other than the `token`. This will trigger a sanity check between the token and the requested site.

## Headers and Alternative Paths

All requests SHOULD set the following headers:

```
Authorization: Bearer <token>
Accepts: application/json
```

The `Accepts` header MAY be omitted if `.json` is appended onto the end of any of the URI documented below. The response MUST be `406 Not Acceptable` if the `Accepts` header has been omitted without appending `.json`.

## Routes

The following routes are available through the API:

### GET Compute Unit Balance

Retrieve remaining number of compute units

```
GET :leader/compute-balance
Authorization: Bearer <token>
Accepts: application/json
```

#### Request Elements

*leader*

Selects which API end point to send the request to (see above for details)

Type: String

#### Response Elements

*computeUnitBalance*

The remaining number of compute units

Type: Integer

#### Example

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "computeUnitBalance": <computeUnitBalance>
}
```

### POST Consume Compute Units

Consume a set number of compute units

```
POST :leader/compute-balance/consume
Authorization: Bearer <token>
Accepts: application/json

{
  "consumption": {
    "reason": "<reason>",
    "private_reason": "<private_reason>",
    "amount": <amount>
  }
}
```

#### Request Elements

*leader*

Selects which API end point to send the request to (see above for details)

Type: String

*reason*

A publicly available comment on why the compute units have been consumed. The response MUST return `400 Bad Request` if omitted or for empty and non-string values.

Type: String

*private_reason*

A privately available reason that is restricted to admins only. This field MAY be omitted.

Type: String

*amount*

The number of compute units to be deducted from the balance. The response MUST return `400 Bad Request` if omitted or non integer values.

Type: Integer

#### Response Elements

*computeUnitBalance*

The remaining number of `compute units`

Type: Integer

*creditsWereRequired*

Flags the request have a non empty pool of `required credits`. The request MAY `allocate` service credits from the `available credits`.

Type: Boolean

*creditsWereAllAllocated* - __Deprecated__

This flag is ambiguous as it does not refer to the depletion of all `available credits`. Instead it means the request SHALL `allocate` all `required credits` from the pool of `available credits`.

This flag MUST NOT be used due to its redundancy and ambiguity.

Type: Boolean/ null

*error*

A error message for why a request failed. It MUST be `null` for all `20x` exit codes. It SHOULD contain a string for all `40x` exit codes.

Type: String/ null

#### Interpreting `computeUnitBalance` and `creditsWereRequired`

All valid requests fall into one of the following three categories based on the sign of `computeUnitBalance` and whether `creditsWereRequired` has been set.

1) The request SHALL `allocate` the `required credits` from the `available credits` if `computeUnitBalance` is non-negative and `creditsWereRequired` is true,
2) The request SHALL NOT `allocate` any `available credits` if `computeUnitBalance` is non-negative and `creditsWereRequired` is false,
3) Otherwise the following applies:
  * `computeUnitBalance` MUST be negative,
  * `creditsWereRequired` MUST be `true`,
  * The request MUST `allocate` all remaining `available credits`, and
  * The `required credits` MUST NOT been satisfied.

