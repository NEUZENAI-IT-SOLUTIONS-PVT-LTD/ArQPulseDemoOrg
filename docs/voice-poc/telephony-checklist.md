# Voice POC — enabling voice and telephony (G2 and G3)

These steps are done in Setup by an admin. The CLI cannot do them.

## G2 — voice preview

1. Confirm the org can use Agentforce Voice.
   - Today the preview says: `Organization does not have access to Voice features`.
   - Ask Salesforce which bundle enables it. The brief lists Enterprise/Unlimited/Developer with Foundations or Agentforce 1 plus the Salesforce Voice add-ons. A free Developer Edition alone is not enough.
2. In `Order_Support_Voice_Agent.agent`, uncomment `modality voice:` and `connection telephony:`.
3. Run `sf agent validate authoring-bundle --json --api-name Order_Support_Voice_Agent`.
4. In Agent Builder → Connections → Voice, select **Continue**. Pick the voice if you want a different one.
5. Test in voice preview:
   - a code with a leading zero, for example 075395;
   - an order number said short, for example "one hundred";
   - interrupting the agent;
   - delivery dates read naturally.

## G3 — real calls

1. Set up the contact center: Salesforce Voice with Amazon Connect, or a supported partner. PSTN transfer numbers are US/Canada only.
2. Claim a phone number and create the voice channel.
3. Create an inbound Omni-Channel flow (Route Work) that sends calls to the agent, with a fallback queue.
4. Check `Order_Support_Voice_Escalation`: it routes the VoiceCall to the `Order_Support` queue on the Phone channel.
5. Add reps to the `Order_Support` queue. Give them the **Available - Order Support** presence status and the `Order_Support_Voice_Rep_Access` permission set.
6. Show the handoff Case to the rep: add Related Order, Is Identity Verified, Caller Intent, AI-Generated Call Summary and Caller Stated Details to the Case layout. Decide how the Case appears next to the VoiceCall (for example `VoiceCall.RelatedRecordId`).
7. Real-call tests:
   - happy path;
   - wrong code twice;
   - no rep available;
   - routing failure;
   - rep sees the Case, verification result, order and summary.
8. Review transcript retention and redaction. Callers say their code out loud.
