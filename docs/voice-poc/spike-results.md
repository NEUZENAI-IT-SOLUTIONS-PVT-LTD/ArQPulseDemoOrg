# Voice POC — spike results (29 Oct 2026)

Org: ArQPulseDemoOrg (Developer Edition). Branch: `feature/voice-order-status-poc`.

## S1 — Verification contract

**Finding:** the callable verification in this org is the Salesforce-managed pair
`SvcCopilotTmpl__SendVerificationCode` + `SvcCopilotTmpl__VerifyCode` (autolaunched flows).

Contract read from `/actions/custom/flow/<name>`:

| Flow                 | Inputs                                                                                   | Outputs                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| SendVerificationCode | `customerToVerify` (email or username)                                                   | `verificationCode`, `authenticationKey`, `customerId`, `customerType` (User or Contact), `verificationMessage` |
| VerifyCode           | `customerCode` (what the caller says), `customerId`, `customerType`, `authenticationKey` | `isVerified`, `customerId`, `customerType`, `messageAfterVerification`                                         |

- The check is **server-side**. `VerifyCode` compares the caller's code using `authenticationKey`; the generated code is never passed back in.
- This matches the published contract of the standard "Verify Customer" action (input `authenticationKey`; outputs `isVerified`, `customerId`), which is part of the topic `SvcCopilotTmpl__ServiceCustomerVerification`.
- The standard action names ("Send Email with Verification Code", "Verify Customer") are **not** exposed in this org as invocable, flow or `GenAiFunction` metadata. Agent Script can only target what the org exposes.
- `customerId` can be a **User** id. The agent must gate on `customerType == "Contact"`, and Apex must also check the id's type.

**Limit to accept:** `SendVerificationCode` also outputs the generated `verificationCode`.

- Mitigation: declare it `filter_from_agent: True`. The compiled output shows `is_displayable: false, is_used_by_planner: false`. The code is never stored in a variable.
- **Unverified:** whether the value appears in session traces or logs. Check with `agentforce-observe` during G1.

**Also unverified (behaviour of the managed flow):** code lifetime, replay after success, resend invalidating the old code, and behaviour for unknown or duplicate emails. These are covered by the manual OTP test script.

## S2 — Agent-user access

Agent user: `order_support_voice_agent@…ext` (Einstein Agent profile). Assigned:

- `AgentforceServiceAgentUser` permission set
- `AgentforceServiceAgentUserPsl` license
- `Order_Support_Voice_Agent_Access` permission set

| Check                              | Result                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------ |
| Object                             | Account R · Contact R · Order R · Case R+C · no Edit, Delete or View All             |
| FLS                                | All needed fields readable; Case handoff fields editable (needed to create the Case) |
| Record access (`UserRecordAccess`) | Read on **all 6** seed orders, edit on none                                          |

**Implication (trust boundary):** Salesforce sharing lets the agent user read every order. Keeping one customer from seeing another's order rests **only** on the verified-contact filter in `GetOrderStatusAction` plus the protected agent variables. Runtime proof still needed: live-action preview.

## S3 — Voice transfer mechanism

- Agentforce Voice escalation runs an **outbound Omni-Channel flow** (Route Work on the VoiceCall, Phone channel, queue plus fallback queue). That flow is attached to the agent's voice connection in Builder. Sources: Trailhead "Set Up the Voice Connection", "Manage inbound call routing".
- Agent Script `connection telephony:` with `outbound_route_type: "OmniChannelFlow"` **compiles**. Local SDK 2.9.27 and `sf agent validate` both pass, and the compiled bundle contains `surface_type: "telephony"`.
- Compiling doesn't prove a real call transfers. That stays **G3**: phone wiring is UI-only.
- Risk: Trailhead says Agentforce Voice in the _new_ Builder was "coming soon" when written. Confirm in Builder that the published agent shows the Voice connection.

## Other checks

- Email: `Messaging.reserveSingleEmailCapacity(1)` succeeds, so the org can send email. The OTP email still has to be confirmed in the inbox.
- Seed data: 4 Accounts, 5 Contacts (`bkareti@gmail.com` on Alex Rivera only; one shared `example.com` email on two contacts), and 6 Orders `00000100`–`00000105`.

## Decision

- **S1 accepted** by the user on 29 Oct 2026: build on the managed pair with the code output hidden and never stored.
- **Condition:** during G1, inspect session traces for the generated code. If it appears, stop and report before G1 is marked done.
