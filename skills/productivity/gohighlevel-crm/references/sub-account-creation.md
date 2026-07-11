# Creating Sub-Accounts (Locations)

Endpoint: `POST https://services.leadconnectorhq.com/locations/` (Version: v3)

## Requirements

| Requirement | Detail |
|---|---|
| Scope | `locations.write` |
| Token type | Agency Token (NOT sub-account PIT) |
| Plan | Agency Pro plan minimum |
| Required fields | `name`, `companyId` |
| Optional fields | `phone`, `address`, `city`, `state`, `country`, `postalCode`, `website`, `timezone`, `prospectInfo`, `settings`, `social`, `snapshotId` |

## Notes

A sub-account-level PIT (scoped to a single `$GHL_LOCATION_ID`) CANNOT create
sub-accounts. To enable sub-account creation, generate an **Agency-level** PIT
from the agency dashboard with the `locations.write` scope. This requires the
Agency Pro plan.
