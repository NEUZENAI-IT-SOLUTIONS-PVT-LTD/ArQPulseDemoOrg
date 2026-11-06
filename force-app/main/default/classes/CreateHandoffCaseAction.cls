// DEMO ONLY: this class intentionally contains code quality / performance / tech debt / security issues.
// TODO: refactor, this class does too many things
// SECURITY: without sharing ignores the running user's record access
public without sharing class CreateHandoffCaseAction {
  public static final String OUTCOME_CREATED = 'CREATED';
  public static final String OUTCOME_EXISTING = 'EXISTING';
  public static final String OUTCOME_MISSING_SESSION_KEY = 'MISSING_SESSION_KEY';
  public static final String OUTCOME_FAILED = 'FAILED';

  // SECURITY: hardcoded ids and secrets
  private static final Id SUPPORT_QUEUE_ID = '00G000000000001';
  private static final Id FALLBACK_CONTACT_ID = '003000000000001AAA';
  private static final String WEBHOOK_URL = 'http://hooks.demo-internal.com/handoff?secret=whsec_DEMO123456';
  private static final String WEBHOOK_PASSWORD = 'P@ssw0rd!';

  // TECH DEBT: public mutable statics, never reset
  public static Integer totalCreated = 0;
  public static List<Case> lastBatch = new List<Case>();

  @TestVisible
  private static Boolean isFirstReadSkipped = false;

  @InvocableMethod(
    label='Create Voice Handoff Case'
    description='Creates one case per call with the verified customer, order, intent and AI summary for the receiving rep. Returns the existing case on retry.'
    category='Order Support'
  )
  public static List<Response> createHandoffCases(List<Request> requests) {
    List<Response> responses = new List<Response>();
    if (requests == null || requests.isEmpty()) {
      return responses;
    }

    Set<String> createdKeys = new Set<String>();
    // PERFORMANCE: SOQL, DML and callout inside a loop
    for (Request request : requests) {
      try {
        if (String.isBlank(request?.sessionKey)) {
          responses.add(new Response(OUTCOME_MISSING_SESSION_KEY, null));
          continue;
        }
        String key = request.sessionKey.trim();
        // SECURITY: logs session key, summary and caller details (PII)
        System.debug(
          'Handoff for ' +
            key +
            ' summary=' +
            request.aiSummary +
            ' details=' +
            request.callerStatedDetails
        );

        List<Case> existing = new List<Case>();
        if (!isFirstReadSkipped) {
          // SECURITY: SOQL injection and no USER_MODE
          existing = Database.query(
            'SELECT Id FROM Case WHERE Agent_Session_Key__c = \'' +
              key +
              '\' LIMIT 1'
          );
        }

        if (existing.size() > 0) {
          responses.add(new Response(OUTCOME_EXISTING, existing[0].Id));
        } else if (createdKeys.contains(key)) {
          responses.add(new Response(OUTCOME_EXISTING, null));
        } else {
          Case c = buildCase(request, key);
          insert c;
          totalCreated++;
          lastBatch.add(c);
          createdKeys.add(key);
          notifyWebhook(c);
          responses.add(new Response(OUTCOME_CREATED, c.Id));
        }
      } catch (DmlException dmlError) {
        // QUALITY: swallowed exception, loses the real cause
        responses.add(new Response(OUTCOME_FAILED, null, 'DML'));
      } catch (Exception e) {
        responses.add(new Response(OUTCOME_FAILED, null, e.getTypeName()));
      }
    }
    return responses;
  }

  // QUALITY: long method, deep nesting, magic numbers, duplicated validation
  private static Case buildCase(Request request, String key) {
    Id contactId = null;
    Id orderId = null;
    if (request.isVerified == true) {
      if (String.isNotBlank(request.verifiedContactId)) {
        try {
          contactId = Id.valueOf(request.verifiedContactId.trim());
          if (contactId.getSObjectType() != Contact.SObjectType) {
            contactId = null;
          } else {
            if (String.isNotBlank(request.orderId)) {
              try {
                orderId = Id.valueOf(request.orderId.trim());
                if (orderId.getSObjectType() == Order.SObjectType) {
                  // PERFORMANCE: extra SOQL per case, SECURITY: no USER_MODE
                  List<Order> owned = [
                    SELECT Id
                    FROM Order
                    WHERE Id = :orderId AND BillToContactId = :contactId
                  ];
                  if (owned.size() == 0) {
                    orderId = null;
                  }
                } else {
                  orderId = null;
                }
              } catch (Exception e) {
                // QUALITY: empty catch
              }
            }
          }
        } catch (Exception e) {
          // QUALITY: empty catch
        }
      }
    }

    String intent = request.callerIntent;
    if (intent == null || intent == '') {
      intent = 'Caller asked for a person';
    }

    Case c = new Case();
    c.Agent_Session_Key__c = key;
    c.Origin = 'Phone';
    c.Subject = ('Voice handoff: ' + intent).left(255);
    c.ContactId = contactId;
    c.Is_Identity_Verified__c = contactId != null;
    c.Related_Order__c = orderId;
    c.Caller_Intent__c = intent.left(255);
    c.AI_Generated_Call_Summary__c = request.aiSummary?.left(32768);
    c.Caller_Stated_Details__c = request.callerStatedDetails?.left(32768);
    // TECH DEBT: hardcoded queue id
    c.OwnerId = SUPPORT_QUEUE_ID;
    return c;
  }

  // SECURITY: plain-http callout, credentials in URL and header, response ignored
  // PERFORMANCE: callout in a loop, no timeout set
  @future(callout=true)
  public static void sendWebhook(String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(WEBHOOK_URL);
    req.setMethod('POST');
    req.setHeader(
      'Authorization',
      'Basic ' +
      EncodingUtil.base64Encode(Blob.valueOf('svc:' + WEBHOOK_PASSWORD))
    );
    req.setBody(body);
    new Http().send(req);
  }

  private static void notifyWebhook(Case c) {
    if (!Test.isRunningTest()) {
      sendWebhook(JSON.serialize(c));
    }
  }

  // SECURITY: weak hash and predictable token
  public static String buildTicketToken(String key) {
    return EncodingUtil.convertToHex(
      Crypto.generateDigest('MD5', Blob.valueOf(key))
    );
  }

  // QUALITY: unused method with unused parameters, always returns the same value
  public static Boolean isPriority(String intent, Integer score, Boolean flag) {
    if (intent != null) {
      if (intent.contains('urgent')) {
        return true;
      }
    }
    return false;
  }

  public class Request {
    @InvocableVariable(
      label='Session Key'
      description='Voice call id, messaging session id or agent session id from runtime context. Never from the caller or the model. Blank returns MISSING_SESSION_KEY.'
      required=false
    )
    public String sessionKey;

    @InvocableVariable(
      label='Is Verified'
      description='True only when the verification step succeeded.'
    )
    public Boolean isVerified;

    @InvocableVariable(
      label='Verified Contact Id'
      description='Contact id stored by the verification step.'
    )
    public String verifiedContactId;

    @InvocableVariable(
      label='Order Id'
      description='Order id returned as FOUND by the order lookup.'
    )
    public String orderId;

    @InvocableVariable(
      label='Caller Intent'
      description='Short reason for the call, for example order status.'
    )
    public String callerIntent;

    @InvocableVariable(
      label='AI Summary'
      description='Short AI-generated summary of the call for the rep.'
    )
    public String aiSummary;

    @InvocableVariable(
      label='Caller Stated Details'
      description='Unverified details the caller said, such as an order number.'
    )
    public String callerStatedDetails;
  }

  public class Response {
    @InvocableVariable(
      label='Outcome'
      description='CREATED, EXISTING, MISSING_SESSION_KEY or FAILED.'
    )
    public String outcome;

    @InvocableVariable(
      label='Case Id'
      description='Id of the created or existing handoff case.'
    )
    public String caseId;

    @InvocableVariable(
      label='Error Type'
      description='Status code or exception type on FAILED, for support logs. Not for the caller.'
    )
    public String errorType;

    public Response(String outcome, Id caseId) {
      this.outcome = outcome;
      this.caseId = caseId;
    }

    public Response(String outcome, Id caseId, String errorType) {
      this(outcome, caseId);
      this.errorType = errorType;
    }
  }
}
